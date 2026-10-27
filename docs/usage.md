# Using StellarCoop

To install the mod, see [INSTALL.md](../INSTALL.md). For what happens behind each feature, see
[how-it-works.md](how-it-works.md).

Close the game before you change any file in the mod folder.

## Keys

The keys work with or without the console. They need the native part (`StellarCoop.dll`).

| Key (default) | Action | Console equivalent |
| --- | --- | --- |
| F5 | Open or close the [co-op menu](#co-op-menu); its first row hosts a session. Within 3 m of a camp phone booth, open the [co-op line](#co-op-line) instead | (none) |
| View held 1 s, on a [controller](#controller) | Open or close the co-op menu, or the co-op line at a booth | (none) |
| F6 | Show the status: one line on screen (see [Notices](#notices)) and in `UE4SS.log` | (a short form of `coop status`) |
| F7 | As the guest, travel to the camp nearest the host, or cancel the travel that `follow_host=always` is about to start; off in this version ([Following the host](#following-the-host)) | `coop travel host` |
| F8 | Leave the session | `coop leave` |
| F9 | While you record a [Doro race](#doro-races) track, set a checkpoint where EVE stands; nothing otherwise | `coop race cp` |
| Enter | During a session, open the [chat](#session-chat) box, then send a line; Esc closes the box | (none) |
| none | Host a session at once, or open the Steam invite dialog again while you host (`host_key`) | `coop host` |

You can change F5, F6, F7, F8 and F9 in the menu's Options page or in [coop-settings.txt](#coop-settingstxt), and
`host_key` in the file only. A key passes its action to the game thread, where the same checks as for the console
command apply (`coop off` included). The log says `key F5: menu`. The other keys then log the usual `OK:` or `STOP:`
line; the menu key logs one only when the menu cannot open.

Before the menu existed, F5 hosted. A settings file written by an older version has no `menu_key` line: the menu then
opens on that file's `host_key` (F5, or the key you set there, such as Shift+F5), and no key hosts at once. To keep a
key that hosts at once, set both `menu_key` and `host_key`.

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
| Copy my code | While you host with a [join code](#join-codes) | Shows the code and runs `coop copy`, which puts it on the clipboard |
| Remove <name> | While a player who is not your Steam friend is in the session you host | Runs `coop remove <SteamID>` when you select it a second time within 3 s |
| Join a friend | Outside a session | Runs `coop join` |
| Join with a code | Outside a session | Closes the menu and opens the [code box](#join-codes) |
| Chat | During a session, with chat on | Closes the menu and opens the [chat](#session-chat) box |
| Options | Always | Opens the settings, below |
| Guide | Always | Closes the menu and opens the [guide](#guide) on its first page |
| Write a bug report | Always | Runs `coop report` |
| Close | Always | Closes the menu |

Under the rows, a status line shows the F6 text and, once your friend is linked, their ping. Below it the menu shows
its own messages, such as `Select again within 3 s to leave.`, or, while it covers the [feed](#session-chat), the
newest notice under 8 s old (for example the result of Join a friend). The menu closes by itself when the game pauses
or shows the mouse cursor for one of its own screens.

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

A controller drives the co-op menu and the [co-op saves' question](#co-op-saves). Hold View (Back on an Xbox 360
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
- B closes the [chat](#session-chat) box and the [code box](#join-codes) as Esc does: nothing is typed or sent. A
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

Each row of the Options page is a setting of [coop-settings.txt](#coop-settingstxt). The rows are in groups: Controls
(the menu, status, leave, travel and race checkpoint keys), Photo mode, Partner (the name tag and the
[partner HUD](#partner-hud)), Ghost (the looks, the [solid partner](#solid-partner-experimental) and the send rate),
Session (who can join a session you host, the [revive](#revive-by-your-friend-experimental), the
[cutscene wait](#cutscene-wait) and [following the host](#following-the-host)), Saves (the [co-op saves](#co-op-saves)
at the title and [shared quests](#shared-quests-experimental)), Combat (shared enemies, same place, who same-place
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
`coop ui reset`: the menu and the boxes close, an open [host's question](#join-codes) is answered with Deny, and the
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

### Status strip above the card

Options > Display > Status line (`status_overlay`) adds a status strip above the card: Off (the default), Compact or
Detailed. Each player's setting is their own, and a change shows at once. The strip shows whenever the
[status line](#the-status-key-f6) says something other than `not in a session` or `waiting for Steam`: while you host
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
- Both players need the same protocol (14) and game build. A mismatch shows a notice on screen (see
  [Notices](#notices)).

The ghost is display only. Items, unlocks and progress are not copied between your two games, except the consumables
you send with [`coop gift`](#cut-mailbox-coop-gift), which leave one co-op save and go into the other. The experimental
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
| Esc, or B on a [controller](#controller) | Close the box |

The box closes when a session starts, when the game pauses or shows the mouse cursor, and outside a world. The native
part checks the code: most codes with a wrong character get `That is not a join code: check its 7 characters.` (see
[how-it-works.md](how-it-works.md#lobby-and-invites)), and a code that leads to no game gets one of the
`Could not join: ...` notices.

A player who is not your Steam friend waits for your answer, whatever Who can join says. Their game shows
`Joined <host>'s game. Waiting to be let in.` Yours shows a question in the middle of the screen, `<name> wants to
join`, with Accept and Deny. It opens on its own, maybe while you walk or use the menu. Deny has the focus, and for
1 s after it shows every key does nothing, so keys pressed for something else never answer it.

- The Up and Down arrows move between Accept and Deny, Enter answers, and Esc denies. W, S, Space and the
  [controller](#controller) do nothing here. While the question is open, the game ignores its own keys and the mod's
  keys do nothing.
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

### Following the host

As the guest on a co-op save, you can go where the host plays through the game's own fast travel. When the host is on
another map, or more than 150 m from you on yours, one notice offers it:
`<host> is in <map>. Press F7 to travel to the camp nearest them.` F7 (`follow_key`) asks the host's game for the 8
camps nearest their EVE, and your game travels to the first of them that it can use (`Travelling to <host>.`). Nothing
changes in the host's game. This has not been tested in game yet.

In this version the travel is off. The game's fast travel does not check whether your save has activated a camp, and
activating a camp counts toward the game's camp trophies. Until the mod can read which camps your save has activated,
no offer shows and F7 shows `The travel did not start. UE4SS.log says why.` The rest of this section describes the
travel as built.

- `follow_host=ask` (the default) shows that notice. With `always`, it reads
  `Following <host> in 5 s. Press F7 to stay.` and the travel starts 5 s later unless you press F7. With `off`, nothing
  shows and F7 does nothing.
- With `follow_key=none`, no notice shows and `always` starts nothing. `coop travel host` still travels.
- The travel reaches only camps your save has activated, as the game's camp menu does. If the game refuses a camp, the
  mod tries the next camp of the list, 3 calls at most.
- Only the 120 camps, phone booths and tetrapods of the game's camp table that lead to one story map can be used.
  Autosave points and the camps of the developer test maps are never sent or taken.
- The travel waits while your EVE is down, while a respawn or another travel is under way, while the game is paused,
  in photo mode or in a menu (the co-op menu included), during a Night Operation run or a cutscene, during a boss fight
  on your side, while an enemy near you is in battle, and for 10 s after the last travel. F7 then shows
  `You cannot travel now. Try again in a moment.`
- `No camp you have found is near <host>.` means that no camp of the host's answer could be used.
  `The travel did not start. UE4SS.log says why.` covers the other failures (see
  [troubleshooting.md](troubleshooting.md#travel-to-the-host-does-not-start)).
- The place a travel brought you to shows no notice. The host's next map change does.

### A player down

When one EVE dies, the other player keeps playing (see [how-it-works.md](how-it-works.md#a-player-down)):

- With [same place](#same-place-experimental) on and `aggro=game` (the defaults), the shared enemies near the living
  EVE fight it. While the guest is on the death screen, the host's game takes back each shared enemy that her game ran
  and that stands within 30 m of the host's EVE, and keeps it until she is up. While the host is on the death screen,
  the guest's game takes the host's common enemies within 30 m of her EVE. Bosses stay the host's.
- While the host is down, the guest's hits on the host's bosses do not count, and the boss's HP goes back to the
  host's.
- A down EVE takes no part in a kill by standing near it (the 30 m of `kill_credit=together`). Its own hits and the
  enemy's record of fighting it still count.
- With both players down, nobody can revive: each respawns at a camp in their own game.

### Revive by your friend (experimental)

With `revive=on` (Options > Session > Friend can revive me; off by default, not tested in game yet), your friend can
revive you where you fell. On the death screen you see `<name> can revive you: wait, or respawn at a camp.` Your
friend sees `<name> is down. Stand next to them for 3 s to revive them.` Once their EVE has stood within 2 m of yours
across, and 1 m up or down, for 3 s in a row, your game calls the game's own in-place respawn on your EVE. You get up
where you fell with full health, and your recovery items are refilled as at a camp respawn. The zone does not reset.
You see `Revived by <name>.` and your friend sees `You revived <name>.` Until then the death screen's respawn works as
usual.

The revive also needs shared enemies running (`shared_enemies=on`, both on co-op saves), your friend alive on your map,
no boss fight on your side and no respawn under way. Only the downed player's setting counts.

During a co-op Night Operation run this revive and its notices stand aside: with `revive=on` the run has its own
revive, with the interact key and a 30 s limit (see [Down and revive](night-operation.md#down-and-revive)). With
`revive=off` a death there ends the run.

### Camp rests in a shared area

Either player can rest at a camp. While both play in one zone within 100 m of each other with same spawns on, only the
host's rest brings the enemies back for both: the host's game resets the zone, and same spawns makes the guest's
enemies follow. The guest's own rest heals her and resets her own game, then same spawns removes again each enemy the
host's game does not have. Two notices on the guest's screen say which case applied:

- `Enemies are back: the area reset in <host>'s game.` when the host's zone resets (a camp rest, or the game resetting
  the zone) while the host is alive;
- `Shared area: only <host>'s camp rest brings its enemies back.` after her own rest there.

A respawn after a death shows neither. Away from the host (another zone, more than 100 m, or same spawns off), the
guest's rest works as in solo play.

### Known limits

- The friend's `<name> is down` notice does not know the downed player's `revive` setting, since no line carries it.
  With `revive=off` (the default) on the downed side, standing next to them does nothing.
- On one map a shared enemy keeps one HP bar at any distance: the host's hits on an enemy 500 m from the guest lower
  her copy's HP too. Its death reaches her game only if she took part in its fight (`kill_credit`).
- A boss fight that the guest starts alone can pair with the host's copy of that boss. Her boss then takes the HP of
  the host's copy.
- A revive refills the recovery items, as a camp respawn does, and the enemies keep their HP. A death resets the zone,
  a boss fight included, which is why no revive runs during a boss fight.

## Guide

The guide has nine pages on what the mod adds, with the Mother Sphere art by timediffer24 on the left. At the mod's
first run it opens on the title screen once the on-screen UI has loaded, and the [co-op saves](#co-op-saves) question
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

## Co-op saves

On the title screen, once the on-screen UI has loaded (a few seconds), the mod asks whether to play on co-op copies of
your saves, while the game uses your own saves (`auto_coop_save=ask`, the default). At the mod's first run the
[guide](#guide) comes first.
[INSTALL.md: Co-op saves](../INSTALL.md#co-op-saves) lists the choices; [saves.md](saves.md#co-op-saves) has the files
and the rules.

| Key | In the question |
| --- | --- |
| Up arrow, W or Z; D-pad or left stick up | Up |
| Down arrow or S; D-pad or left stick down | Down |
| Enter or Space; A | Select |
| Esc; B | Decide later (while the copies are made: no switch, the game stays on your own saves) |
| Left click | The choice under the mouse |

The question opens with Convert and play co-op (or Play co-op) selected. For 1 s after it shows, Enter, Space, A and a
click do nothing, so a press meant for the title screen does not answer it; the arrows, Esc and B act at once. While
the question shows, the game ignores its own keys and a dark shade over the screen takes the mouse, so neither reaches
the title menu. The game gets its keys back 150 ms after the question closes. A controller the mod cannot read (see
[Controller](#controller)) cannot answer it: after 60 s with no key, it closes as Decide later, and
`auto_coop_save=always` or `off` skips it. Choosing Continue or Load Game before the question shows loads your own
save; the question comes back at the next title screen. `coop ui reset` closes it as Decide later.

A friend's invite accepted on the title screen waits until a save loads (`Invite held: joining once your save has
loaded.`). The question then starts with `Your friend's invite waits until your save loads.` If you already answered
Play solo normally or Decide later on that title screen, it asks once more when the invite comes.

`auto_coop_save=always` makes the copies and switches to them at each title screen without asking; `off` turns the
question and the automatic copies off. Options > Saves > Co-op saves changes it at once. The result shows as a notice in
the feed (see [Notices](#notices)). While the game uses the co-op copies, the title screen shows `CO-OP SAVES` at the
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

### Cutscene wait

While a cutscene plays in the host's game and both EVEs are on one map, the guest's game holds the same pause as photo
sync, and the guest sees `<host> is watching a cutscene. Your game waits until it ends.` once per pause. The pause ends
when the cutscene ends, and otherwise as the photo pause does (connection lost, F8, `coop off` or `photo_freeze_max`).
It works with any `photo_sync` value. `cutscene_wait=off` (Options > Session > Wait for host cutscenes) keeps the
guest's game running. Only the host's cutscenes pause the other game.

Each game looks for the game's own cutscene player once a second while linked. Whether every story scene, dialogue and
boss intro counts as a cutscene there has not been checked in game yet.

## Doro races

A Doro race is a run along a track of checkpoints that you record, for one player or two. Each racer is drawn as a
Doro (Dororong): your EVE on your screen, and your ghost on your friend's. From GO, EVE drives like a rally car (see
[Driving](#driving)); her jumps, dodges and camera stay the game's. Doro races have not been tested in game yet.

### Recording a track

1. Stand where the race starts, facing the way it goes, and type `coop race record <name>`. The name is 1 to 24
   characters of `a-z`, `0-9`, `_` and `-`. The start line is where EVE's feet are, facing her way.
2. Run the route. At each checkpoint, press F9 (`race_key`) or type `coop race cp`. The checkpoint is where EVE's feet
   are at that moment, with a 12 m radius. It must be at least 15 m from the one before it (from the start line for
   the first), or it is refused with `Too close: 15 m at least between checkpoints.` A track holds at most 64
   checkpoints, and the last one is the finish.
3. Type `coop race save` to write the track to `coop-track-<name>.txt` beside `coop-settings.txt`. It replaces a
   track of the same name, and it needs 2 checkpoints at least. `coop race save <laps>` (1 to 9) makes a circuit,
   which needs the last checkpoint within 30 m of the start line. `coop race cancel` drops the recording and writes
   nothing.

The log line `[StellarCoop][DR] track <name> saved: <n> checkpoints, <laps> laps, path <m> m in <s> s` gives the
distance you ran and how long it took. Recording works on any save. A checkpoint on another map than the start line's
is refused, and F9 does nothing while no track is being recorded. The mod ships no track of its own.

### Starting a race

`coop race start <name>` arms a race on `coop-track-<name>.txt`, on a co-op save only. The host starts every race: a
guest's `coop race start` is refused, and the guest's game takes part when the host starts one. The start is also
refused while a Night Operation run is on, while a track is being recorded, when the track is on another map than
yours, and when your friend is on another map or their map is not known yet. `coop nightop start` is refused while a
race is armed.

- With no session, you race alone against the clock.
- With a friend linked, your game sends the track to theirs, which checks it and joins the race. They need no track
  file, and their screen says `<host> starts a race: walk to your start.` When their game does not join, you race
  alone, and your notice says why: they are on another map, their game could not read the track, they do not play a
  co-op save, or no answer came within 10 s.
- During `coop loopback` with no friend linked, the loopback ghost races as the second player, which tests the
  two-player race on one PC. It walks 2 m to your right as you faced when it appeared, and keeps that side. Start the
  loopback facing the way the race goes: the ghost then stands in the guest's slot while you stand in yours.

### Slots and countdown

The start line has two slots, 3 m apart across its facing: the host's on the left and the guest's on the right. Alone,
you take the left one. A marker labelled `Your start` stands over yours, and a Doro stands at the centre of the line.
Walk to your slot: the mod moves nobody. You are in it within 2.5 m of its centre, and out of it past 3 m.

Once every racer has stood in their slot for 1 s, the host's game starts a 4 s countdown: 3, 2, 1, then GO. On the
guest's PC the countdown starts when the host's line arrives, less half the ping.

Leaving your slot before the countdown holds the start. Leaving it during the countdown is a false start: the
countdown stops on both screens with `False start: back to your start.`, and the 1 s check starts again. A false
start has no penalty.

### Driving

From GO until your own result (your finish or a DNF), EVE drives like a rally car:

- The left stick points where you want to go, relative to the camera, as outside a race. Doro turns toward it at 220
  degrees a second when it stands, and slower as it gets faster, down to 75 degrees a second at top speed. It speeds
  up along the way it faces, quickly at first and slowly near its top speed of 22 m/s. EVE runs at 5 m/s and sprints
  at 7. A stick pushed halfway gives half the throttle.
- Pulling the stick back, more than 120 degrees from where Doro faces, brakes down to 3 m/s without turning. With the
  stick released, Doro coasts and loses 2.5 m/s each second.
- To drift, hold R2 on a pad or B on the keyboard above 4 m/s, or steer more than 45 degrees off the way Doro faces
  above 12 m/s. Doro then keeps its speed and slides sideways while it turns, at 1.4 times the turn rate, until the
  slide is under 1.5 m/s.
- Over a crest faster than 9 m/s, Doro leaves the ground. In the air it keeps its speed and turns at 0.3 times the
  rate.
- A wall hit faster than 9 m/s that takes 40% of the speed at once makes Doro stumble for 0.6 s: no throttle, half
  the steering.
- While a dodge or another of the game's root-motion moves carries EVE, the driving waits.

Both players race with the host's driving values: the host's game sends them after the track, and a guest's game that
gets a track without them stays out of the race. They are starting values, not yet tuned in game.

`drift_keys` in `coop-settings.txt` names the drift keys: Unreal key names, at most 4, or `none` to drift by steering
alone. R2 still picks up items within reach during a race, as it does outside one.

To drive EVE, the race sets four values of her movement component to 0 (`MaxAcceleration`, `GroundFriction`,
`BrakingDecelerationWalking` and `BrakingFrictionFactor`), so her movement keeps the velocity the race gives it each
frame, and turns her to Doro's heading. Floors, walls, slopes and gravity stay the game's. Your result, `coop race
quit`, a DNF, `coop off`, a map change and the race's first Lua error put the four values back. While it drives,
`coop-drive.txt` holds them, so the next Lua load (Ctrl+R) puts them back when this one could not. If EVE no longer
speeds up or stops after a race, press Ctrl+R.

Test and tuning commands, left out of the usage line:

- `coop race drive` shows the host's driving values and how the velocity reaches EVE's movement.
- `coop race drive probe`, on a co-op save with no race armed: EVE goes straight ahead at 15 m/s for 3 s through
  impulses, then 3 s through writes of her velocity, then drives with your stick as in a race until
  `coop race drive off`.
- `coop race drive <name> <value>` changes one driving value for your next races, until the mod reloads. The names are
  `top` (cm/s), `accel`, `brake` and `coast` (cm/s per second), `grip` and `drift_grip` (tenths a second: how fast a
  slide fades), `turn_slow` and `turn_fast` (degrees a second, standing and at top speed) and `drift_angle` (degrees).
  Each value is a whole number, kept within its range.
- `coop race drive feed impulse|struct` picks how the velocity reaches her movement: an impulse each frame (the
  default) or a write of its velocity.

During a drive, `UE4SS.log` has a line once a second, `[StellarCoop][DR] drive v=<cm/s> vz=<cm/s> asked=<cm/s>
yaw=<degrees> heading=<degrees> air=0|1 root=0|1 drift=0|1 stumble=0|1`, and a line for each drift key pressed or
released, each wall hit and each crest. `asked` is the speed the car gave the last frame, `yaw` EVE's facing as read
one frame after the car turned her.

### Rules

- Checkpoints count only in order. A checkpoint counts when EVE's path from one frame to the next comes within its
  radius horizontally and within 6 m vertically, at any speed. A marker over the next checkpoint shows its distance,
  and an arrow at the edge of the screen points to it when it is off screen or behind you. A Doro stands at the next
  checkpoint and another at the one after it. The Doro at the finish hops in a loop.
- `MISSED CHECKPOINT <n>`: you entered a later checkpoint while checkpoint `<n>` was still due. Nothing counts until
  you go back through it.
- `WRONG WAY`: the distance to the next checkpoint grew 20 m past its lowest since your last checkpoint, after you ran
  more than 25 m. It clears once that distance drops by 10 m.
- Neither a missed checkpoint nor a wrong way has a penalty other than the time it costs.
- On a circuit, the checkpoints repeat from the first one each lap. You finish at the last checkpoint of the last lap.
- Each racer is timed from their own GO by their own game's clock. Pausing the game does not stop it.

A DNF (did not finish) ends your race. A notice says why:

| Notice | Cause |
| --- | --- |
| `Moved more than 20 m at once.` | EVE moved over 20 m in one frame: a fast travel, a respawn at a camp after a death, or any other warp. After a frame that took long (a hitch), the limit is the distance twice the top speed covers in that time, when that is more |
| `Left the map.` | A map change, or no EVE in the world for 2 s (a load, the title screen) |
| `The session ended.` | The link with your friend ended |
| `Not finished 60 s after the winner.` | You were still racing 60 s after the first racer finished |
| `Over the 15 min limit.` | You were still racing 15 min after GO |

`coop race quit` and `coop off` end your race as a DNF too, with the command's answer instead of a notice. Before GO,
the host's quit or map change cancels the race for both players (`Race cancelled.`). A guest who does the same leaves
the race. Before the countdown the host then races alone; during it, the guest stays in the race as a DNF, so `POS`
counts two racers and the results list the guest as `DNF`.

### Results

During the race, the panel at the top centre shows `DORO RACE`, your time (`1:23.45`), `CP`, `LAP` and `POS`. Your
place comes from laps, checkpoints and the distance to the next checkpoint, your friend's from where their ghost is.

Once every racer has finished or is out, `RESULTS` takes the panel's place for 10 s, with each racer's place and time,
or `DNF`. Times within 10 ms share a place. The host's game sends the ranking, so both screens show the same one. While
they stand still, the winner's Doro hops in place and the other Doro plays its tired animation. Then the race closes:
its Doros go, and EVE and the ghost are drawn as themselves again.

Two flags can show under `RESULTS` for your own run. Neither changes the ranking.

- `fast run`: for 1 s or more, EVE moved faster than 5.5 m/s horizontally while she was not sprinting and not in the
  air. The flag was there for Tachy mode, which runs faster. A driven run's speed no longer depends on Tachy mode, and
  the flag does not show while the race drives EVE.
- `paused`: the game was paused, or showed one of its own screens, for 2 s or more.

Each PC logs one line per race that reaches its results there: `[StellarCoop][DR] result id=<id> track=<name> ms=<ms>
clock=<s> time=<s> flags=<n> rank=<place>`. `ms` is your time in milliseconds, `clock` and `time` measure the race with
two different clocks (for a bug report), `flags` adds 1 for a fast run and 2 for paused, and `rank` is your place. `ms`
and `rank` read `-` after a DNF, and `track` reads `-` on the guest's PC.

The panel, the banners and the results hide while the game is paused or shows one of its own screens. With the
co-op UI off (`coop ui off`, or after an engine error), they do not show, and the banners other than the countdown
come as notices on the line above EVE.

### The Doro look

From the start of a race on your PC until it closes, your EVE is drawn as a Doro. The Doro stands at EVE's feet, walks
and runs on two legs, runs on all fours while she sprints, and hops when she jumps. Your friend's ghost is drawn as a
Doro from the moment their game joins the race. If it does not join, it stays EVE on both screens.

While the race drives EVE, her Doro runs on all fours from 60% of the top speed, plays its run up to 3 times faster,
faces where it is heading (so it shows its side in a drift), leans into bends, dips its nose when it lands and plays a
tired hop when it hits a wall. Your friend's Doro does the same from their ghost's movement, except the tired hop.

To draw the Doro, the look hides EVE's mesh parts in game, and sets her main mesh to keep animating while hidden. It
also hides the body of the drone that follows EVE, when it is within 30 m of her as the look starts. The drone's light
and signals keep working. The race's end, `coop race quit`, `coop off`, a map change and the look's first error undo
these changes. While the look is on, `coop-look.txt` holds what it changed, so the next Lua load (Ctrl+R) undoes them
when this one could not. If EVE or the drone stays hidden, see
[troubleshooting.md](troubleshooting.md#eve-is-invisible-or-only-a-doro-shows).

Each Doro keeps its animations loaded while it stands. The first Doro of a race loads them all at once, so it can take
a moment to appear, and none loads during the race. While the look is on, `UE4SS.log` has a line once a minute,
`[StellarCoop][DR] look hid=<n> tick=<t>->0 rehid=<n>/min retick=<n>/min reload=<n>/min reload_ms=<ms>`. `reload`
counts the Doro animations loaded again since the look's Doro appeared, and `reload_ms` the total time they took. In
0.5.0-beta.1 these loads froze the Doro for a moment when EVE sprinted. It should read 0.

While the look is on, your friend's game receives your EVE's parts as hidden. In a race their game joined, they see
your ghost as a Doro. Otherwise your ghost on their screen shows its name and marker but no body until the look ends.
After a race, it can show no body for about 1 s.

Two test commands are left out of the usage line. Both need a co-op save, except `coop race look off`:

- `coop race look on` turns on the look on your EVE and the Doro on your friend's ghost, with no race.
  `coop race look off` turns both off, on any save.
- `coop race probe doro` shows a Doro 3 m in front of EVE that plays each of its animations in turn, for about 45 s,
  with a `[StellarCoop][DR]` line in `UE4SS.log` for each step.

### Limits

- Two players at most. The host starts every race, and only the host needs the track file.
- Both players must be on the track's map.
- Enemies stay as they are: each game runs its own fights during a race, and shared enemies, same place and same
  spawns work as usual. Record tracks through ground you have cleared.
- A race gives no reward, item, progress or achievement, and writes nothing to a save. Its Doros are display only,
  with collision off: nothing can hit them, and they cannot die.

### Track files

A track file is plain text:

```
SBR 1
map /game/art/bg/worldmap/e03_wasteland_p/e03_wasteland_p
laps 1
grid -42511 -14642 -2682 -165
cp -46580 -15709 -2473 1200
cp -49676 -17231 -2472 1200
```

`grid x y z yaw` is the start line's centre in centimetres and its facing in degrees. Each `cp x y z r` line is a
checkpoint's centre (EVE's feet when it was set) and its radius in centimetres. With the game closed, you can change a
radius by hand, from 300 to 3000. The file keeps this form: whole numbers, single spaces, 1 to 9 laps, 2 to 64
checkpoints, each at least 15 m from the one before it (the first from the start line), at most 4096 bytes.
`coop race start` refuses a file that breaks a rule, with the reason.

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
| `coop travel host` | As the guest, travel to the camp nearest the host (F7), or cancel the travel that `follow_host=always` is about to start; off in this version ([Following the host](#following-the-host)) |
| `coop status` | Print the full state: link, friend, notices, pose path, save slot, ghost |
| `coop report` | Write `coop-report.txt`, to send with a bug report |
| `coop mark [text]` | Write a numbered line in your logs and your friend's, to line up the steps of a [test played together](#coop-mark) |
| `coop where` | Print one line of positions to compare between two PCs |
| `coop puppet` | Turn the ghost on or off by hand |
| `coop basesuit` | Draw the ghost's body and hair on the base suit, or back on her own meshes |
| `coop look` | Show which looks are on |
| `coop look <cloth\|dyes\|effects> <on\|off>` | Turn one look on or off until the mod reloads |
| `coop wear [<name>\|off [hair\|suit]]` | Put a [cut hair or suit](#cut-hairs-and-suits-coop-wear) on your EVE (display only, untested in game), or give the game's back |
| `coop lines [<name>\|stop]` | Show the subtitles of a [scene cut before it was voiced](#cut-scene-lines-coop-lines) in the chat's feed, or play unused voice takes, or end it (untested in game) |
| `coop emote [list\|<name>\|off]` | Play one of [EVE's clips](#emotes-coop-emote) (a photo-mode pose held until she moves, a wave, a clip of the Cut category; untested in game), list them or end it |
| `coop loopback <delay ms> <jitter ms> <loss %>` | Run your own ghost through a simulated network on one PC |
| `coop loopback off` | Stop the loopback |
| `coop record` / `coop record off` | Record what you send (table and poses) to `coop-record.bin` |
| `coop replay` / `coop replay off` | Play `coop-record.bin` back as a ghost, in a loop |
| `coop nightop [start [easy\|normal\|hard\|nightmare] [noaggro\|nomove]\|stop]` | [Night Operation's run](night-operation.md#the-solo-run-coop-nightop) at one of four [levels](night-operation.md#levels), solo or, started by the host at his level, [for both players](night-operation.md#the-co-op-run) (untested in game, co-op save only; `stop` on any save) |
| `coop nightop revive` | In a co-op run with `revive=on`, while your EVE is down: revive her yourself, a few times a run ([Down and revive](night-operation.md#down-and-revive)) (untested in game, co-op save only) |
| `coop nightop shop` | Night Operation's [reward shop](night-operation.md#the-shop-screen-coop-nightop-shop) in the game's own shop screen, your points as Beta Seeds, with its seven items (two cut stimpacks and the cut [Shock Bolt](#cut-ammo-shock-bolt) ammo among them) (untested in game, co-op save only) |
| `coop nightop buy [<n> [count]]` | The same shop from the console: your points and its seven items, or a buy of 1 to 10 of one of them (untested in game, co-op save only) |
| `coop challenge [<name>\|stop]` | [Challenges](night-operation.md#challenges-coop-challenge): the list with each best run, a start by name or number (1 to 5), or the end of the run that is on (untested in game, co-op save only; solo but the [Shooting Range](night-operation.md#shooting-range), which the host can start for both players; `stop` on any save) |
| `coop no [heal\|rule\|spawnpt\|actor]` | Night Operation probe (research preview, co-op save only) |
| `coop recruiter [off]` | Night Operation recruiter (research preview, co-op save only) |
| `coop scene [emil\|orcal\|stop]` | Play a [cut scene](#cut-scenes-coop-scene) through the game's cutscene player (untested in game, co-op save only), list the scenes or stop the one that plays |
| `coop lion [intro]\|rows\|control`, `coop lion brain skulling\|lurker`, `coop lion unfreeze [init]` | The [cut Lion](#cut-boss-coop-lion) as an enemy to fight (test command; in its tests it fought but did not animate): spawn one, with its entrance first; add its rows only; spawn an Antlion through the same call; pick the tree of the next Lions; put back the engine switches that can freeze its mesh (spawns on a co-op save only) |
| `coop gardener fight [intro\|half\|skulling\|rows]` | The [cut Gardener](#cut-enemy-coop-gardener-fight) as an enemy to fight (test command, untested in game): spawn one, with its entrance first, at half size, or with the Lion's tree; add its rows only (spawns on a co-op save only) |
| `coop tendril fight [rows]` | The [cut Tendril](#cut-enemy-coop-tendril-fight) as an enemy to fight (test command, untested in game): spawn one, with the Shows of its attacks built in memory first; add its rows and build its Shows only (spawns on a co-op save only) |
| `coop chainspin` | EVE's [cut Tachy Mode ChainSpin](#cut-tachy-skill-coop-chainspin), started once while she is in Tachy Mode (test command, untested in game, co-op save only) |
| `coop mxiii` | A camp travel into the [cut Matrix XIII dungeon](#cut-dungeon-coop-mxiii-experimental) (experimental test command, untested in game; needs the zMXIII_P test pak, which the mod does not ship; solo, co-op save only) |
| `coop fly on\|off`, `coop slowmo on\|off` | The game's [developer flight and slow motion](#debug-flight-and-slow-motion-coop-fly-and-coop-slowmo): a third press of the space bar in the air flies (test commands, untested in game; on on a co-op save only) |
| `coop glide on\|off` | EVE's [cut glide](#cut-glide-coop-glide) while Jump is held in the air (test command, untested in game; on on a co-op save only) |
| `coop shortcut` | List the [cut Load Shortcut menu's saves](#cut-load-shortcut-saves-coop-shortcut) in `coop-link.log` (test command, untested in game, any save; loading one is held back) |
| `coop devmenu [list\|<row>]` | The rows of the game's [developer menu](#developer-menu-coop-devmenu-and-coop-devinfo) that still work: the list, or one row on EVE or the enemies near her (test command, untested in game; a row on a co-op save only) |
| `coop devinfo quest\|player\|off` | The game's [quest debugger or player info panel](#developer-menu-coop-devmenu-and-coop-devinfo), opened or closed (test command, untested in game, any save) |
| `coop gift [send <item> [count]\|take [n]]` | The [cut mailbox as a gift box](#cut-mailbox-coop-gift): what waits in yours, a gift of 1 to 10 consumables to your linked friend, or the gifts that wait put into your inventory (untested in game, co-op save on both sides) |
| `coop race record <name>\|cp\|save [laps]\|cancel` | Record a [Doro race](#doro-races) track (untested in game) |
| `coop race start <name>\|quit` | Start a Doro race on that track as the host or alone (co-op save only), or leave it |
| `coop fight on\|off\|status` | Shared enemies (experimental, on by default, co-op save only) |
| `coop fight probe\|record\|replay`, `coop fight test hp\|sh\|st <change>`, `coop fight test kill` | Shared enemies' solo test tools (experimental, co-op save only) |
| `coop fight pilot status\|probe\|on\|off`, `coop fight pilot test freeze\|cmc\|drive\|replay\|target\|exec` | [Same place](#same-place-experimental) (experimental, on by default) and its solo test steps |
| `coop fight pilot test bstart\|phase\|finish\|summon` | Solo tests of [shared bosses](#shared-bosses-experimental) on the boss copy of a replay (experimental) |
| `coop fight spawn probe` | Solo probe of [same spawns](#same-spawns-experimental) (experimental, co-op save only) |
| `coop quests on\|off\|status` | [Shared quests](#shared-quests-experimental) (experimental, off by default, co-op save only) |
| `coop quests probe\|record\|replay` | Shared quests' solo test tools (experimental, co-op save only) |
| `coop quests force <number>` | As the guest, make the step that quest holds for your own kill, or for a place the game's tables cannot give, where you stand; type it twice within 10 s |
| `coop freeze <seconds>` / `coop freeze off` | Hold the [synced photo mode](#synced-photo-mode)'s pause alone, 1 to 3600 s |
| `coop revive test` | Solo test of the [revive](#revive-by-your-friend-experimental): at the death screen, call the game's in-place respawn on your EVE once (co-op save only, no session, with `coop loopback 0 0 0` running so that your life state is read) |
| `coop guide` | Open the [guide](#guide) on its first page, on the title screen or in the world |
| `coop ui reset` | Close the co-op menu and the chat box, and give the game its keys back at once |
| `coop ui off` | Remove the co-op menu, the chat box, the feed, the partner HUD, Night Operation's card and result panel, the guide and the co-op saves' question until the mod reloads |
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
  reason (`protocol` for a file made under another protocol, which includes every file made before protocol 14). It
  then plays the file in a loop as the remote side, each pose re-stamped as if sent now, until `coop replay off`, which
  removes the ghost. The generation, map and positions stay as recorded: the ghost wears the recorded outfit and walks
  where you walked, with no offset, and the map gate applies.
- During `coop loopback` with no friend linked, a chat line you send comes back as your friend's, and your own HP,
  shield and gauges stand in for theirs on the partner card (`mate=` in `coop status`).
- The loopback and the replay never run together. Either one replaces a linked friend until it is off: nothing is sent
  to the friend meanwhile, what they send is ignored, and their ghost is removed. When it stops, you are linked again:
  your table goes to them at once, and theirs comes back within 5 s: their game sends it again when your poses reach
  them after the gap. A recording can run at the same time as either one.

See [how-it-works.md](how-it-works.md#loopback-record-and-replay) for the parts of the pipeline each one tests.

### Night Operation previews

`coop no` (the probe) and `coop recruiter` (the cut recruiter) are research previews of the cut Night Operation mode,
not a playable mode. They run only on a [co-op save](#co-op-saves) and need preparation first: read
[night-operation.md](night-operation.md) before you use them. Otherwise they stop with:

```
STOP: coop no runs only on a co-op save (INSTALL.md: Co-op saves); now <the slot line>
```

(`now no slot status` without the native part.)

`coop nightop`, Night Operation's run and its shop, and `coop challenge`, the challenges, run only on a co-op save too,
with the same `STOP:` line under their own names, except `coop nightop stop` and `coop challenge stop`, which work on
any save. See [night-operation.md](night-operation.md#the-solo-run-coop-nightop) and
[Challenges](night-operation.md#challenges-coop-challenge).

- With no Steam session, `coop nightop start` starts a solo run. A level may follow `start`: `easy`, `normal` (the
  same as none), `hard` or `nightmare`. It sets the number of monsters in each wave (15 to 40 in all), the time limit
  (9:00 to 7:00) and the shop points (50 % to 200 %). See [Levels](night-operation.md#levels).
- In a session, only the host starts a run, at his level, and it is for both players. The guest's game checks her
  side and joins without a question, or the host gets a notice with the reason she cannot. On the guest's game the
  command answers `STOP: the host starts a co-op run`. See [night-operation.md](night-operation.md#the-co-op-run).
- In a co-op run, a dead EVE whose player has `revive=on` is down for 30 s. Her partner revives her by holding the
  interact key (F, or the pad's right trigger) for 3 s next to her, or she types `coop nightop revive` (3 times a run
  at easy, 2 at normal, 1 at hard, none at nightmare). See [Down and revive](night-operation.md#down-and-revive).
- `coop nightop shop` opens the game's own shop screen with the seven items, your points as Beta Seeds while it is
  open (see [below](#night-operations-shop-screen-and-roxannes-choices)). `coop nightop buy` lists the points your runs
  gave and the seven items, and `coop nightop buy <n> [count]` buys 1 to 10 of item n into the co-op save. Items 5 and
  6, the cut Burst and Beta Stimpacks, need table rows the native part adds with the Lion's (see
  [Cut boss](#cut-boss-coop-lion)), and item 7, the cut [Shock Bolt](#cut-ammo-shock-bolt) ammo, rows of its own: a buy
  of one asks for them first, and the screen asks for both. Your points are in `coop-night-<steamid>-<index>.txt` in the
  mod folder, one file per Steam ID and co-op slot. See [night-operation.md](night-operation.md#the-reward-shop).
- `coop challenge range` (or `coop challenge 5`) starts the Shooting Range: three rounds of 3, 4 and 5 of the game's
  target dummies, all around EVE, in 2:00. It is made for the drone's ranged mode, which needs the gun the story
  unlocks; the sword reaches the dummies too. Alone it needs no Steam session; in a session the host starts it for
  both players, as a co-op Night Operation run. Its score also shows on the cut test widget `WB_ShootingTrainingTest`.
  See [night-operation.md](night-operation.md#shooting-range).
- On a co-op save, Roxanne in Xion offers Night Operation (Easy, Normal, Hard) and its supplies in her dialogue. See
  [night-operation.md](night-operation.md#night-operation-at-roxannes).

The ghost, the link and every other command except `coop fight` (below), `coop race start`, `coop race look on`,
`coop race probe doro` and `coop race drive probe` (see [Doro races](#doro-races)), `coop leviathan show`,
`coop leviathan cam` when it turns the camera on (and the same two in the six other
[viewer commands](#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril)), `coop lion`, `coop lion intro`,
`coop lion control`, `coop gardener fight` with no word, `intro`, `half` or `skulling`, `coop tendril fight` with no
word, `coop chainspin`, a scene of `coop scene`, `coop fly on`, `coop slowmo on`, `coop glide on`, a row of
`coop devmenu` and `coop gift` (below) run on any save.
`coop fight pilot` runs on any save too, since same place only moves enemies while shared enemies run.

### Night Operation's shop screen and Roxanne's choices

`coop nightop shop` and Roxanne's choices are described in
[night-operation.md](night-operation.md#the-shop-screen-coop-nightop-shop) and
[night-operation.md](night-operation.md#night-operation-at-roxannes). Both run on a co-op save only. The native part
reports them in `coop-status.txt`:

- `shop=`, the shop's rows batch, in the same forms as the `lion=` line (see [Cut boss](#cut-boss-coop-lion)):
  `shop=off` before an ask, `shop=rows added=6/6 asks=1 spawns=? char=0/0 skills=0/0 stance=0/0` once the 6 rows are
  in.
- `nightshop=`, the shop screen: `nightshop=off` before the first ask, then
  `nightshop=<open|closed|?> seeds=<n|?> asks=<a> last=<ask>:<why>`, where `open` means a shop screen is open (any,
  the game's own too), `seeds` is the inventory's Beta Seeds (`?` while unread: no player data yet, or the game's logic
  busy that moment), `asks` the requests handled so far and `last` the last one (`open`, `open_bolt`, `close` or
  `watch`) with why it did nothing (`none` when it did): `client` or `manager` (no game client or UI manager yet),
  `flow` or `phase` (not in game, or not playing), `open` (a shop screen is already open), `game` or `logic` (the
  game's open gave nothing), `closed` (nothing to close), `name` (no FName). `nightshop=fault asks=<a> where=<where>`
  after a fault in its calls.
- `roxanne=`, her choice list: `roxanne=<unread|absent|on|off|other> asks=<a> want=<on|off> why=<word>`. `on` is the
  list of six, `off` her own two, `other` a list the mod does not know and never touches, `absent` no list of hers in
  the game's cache, `unread` the cache not read yet. `why` is `none`, or why the last request did nothing: `unread`,
  `absent`, `other`, `name`, `alloc` (the game's allocator gave nothing), or `busy`, `net` and `gate` (the rows' gate
  stayed shut for 300 frames: the game's logic busy, a net mode other than 0, or its globals unread).
  `roxanne=fault asks=<a> where=<where>` after a fault.

The native part's own lines, in `coop-link.log`:

| Line | What it answers |
| --- | --- |
| `shop rows: 6/6 added through SB's AddRow 0x14417ba30, 0 refused` | The shop's 6 rows are in |
| `nightshop watch: the shop screen and the Beta Seeds read every 250 ms` | The reads started (the screen's first request) |
| `nightshop open_bolt: SB's shop screen opened on Shop_NightOperation_CoopBolt` | The game opened its shop screen on the shop that sells the Shock Bolt (`open` and `Shop_NightOperation_Coop` without it) |
| `nightshop open refused: phase` | The screen did not open: the game was not playing (the other words as in the `nightshop=` line) |
| `nightshop fault 0x... in ... reading 0x...: no Night Operation shop screen until the game restarts (coop nightop buy still works)` | A fault in the screen's calls. Everything else keeps running |
| `roxanne on: her list reads on` | Her choice list now holds the six rows |
| `roxanne off: her list reads off` | Her two choices are back |
| `roxanne on refused: other, her list reads other` | Her list was not the two rows the mod knows, so it changed nothing |
| `roxanne fault 0x... in ... reading 0x...: Roxanne's choices stay as they are until the game restarts` | A fault in the list's calls |

### Cut enemy preview: `coop leviathan`, `coop gardener` and `coop tendril`

The game's files hold enemies that have not been seen in the game. These test commands, left out of the usage line,
show three of them:

- `coop leviathan`: Naytiba 10, the Leviathan, in `/Game/Art/Character/Monster/CH_M_NA_10/`.
- `coop gardener`: Naytiba 1, the Gardener, in `/Game/Art/Character/Monster/CH_M_NA_01/`. It is an artillery Naytiba
  about 20 m tall at scale 1, with its own textures. The prologue shows its mesh far away as scenery; its fight and its
  Data Bank entry were cut. [`coop gardener fight`](#cut-enemy-coop-gardener-fight) spawns it as an enemy.
- `coop tendril`: Naytiba 6, the Tendril, in `/Game/Art/Character/Monster/CH_M_NA_06/`. It is a prototype mesh
  (`CH_M_NA_06_test`, about 7 m tall) with 44 animations and blend spaces and no material.
  [`coop tendril fight`](#cut-enemy-coop-tendril-fight) spawns it as an enemy.

The three commands take the same words, described below with `coop leviathan`, and share one display and one
[free camera](#free-camera) with four more commands for
[other cut models](#other-cut-models-coop-mann-coop-nier-coop-orcal-and-coop-enya). One model is shown at a time: a
`show` of another one removes the first, and its answer starts with
`Leviathan removed: one cut model is shown at a time.` (or the name of the other model). They never spawn
an enemy or a character. What they show is a plain actor with one mesh and collision off, like the Doros of a race, so
nothing of it can fight, die or reach a save. Their lines go to `UE4SS.log` as `[StellarCoop][LV]`.

- `coop leviathan` or `coop leviathan list` only reads. It logs one line for each mesh, skeleton, animation, blend
  space and Blueprint class it looks for: `missing`, or the object's class, with the skeleton of a mesh or an
  animation and the parent class of a Blueprint class. Two more `list asset` lines give the same for
  `M_Leviathan_Despawn`, from the game's despawn shows, and for `Default` in the Leviathan's folder. Then it logs
  each CharacterTable row whose name, or one of its name fields such as `Type` or `RefAppearance`, contains `NA_10`
  or `eviathan` (Leviathan, and Reviathan as the statue spells it), with the row's character ID and `MeshScale`, and
  the number of rows it read.
- `coop leviathan show [body|a|b|tentacle|statue] [<distance m>|auto] [<height m>|auto] [<scale>]` puts one mesh in
  front of EVE, facing her, and turns on the [free camera](#free-camera). `body` (the default) is `CH_M_NA_10`, `a`
  and `b` are `Leviathan_A` and `Leviathan_B`, `tentacle` is `M_LeviathanTentacleA` and `statue` is `C_Reviathan`, a
  static mesh from the game's secret room assets. The distance is in metres, up to 5000; `auto`, the default, is 1.6
  times the radius of the mesh's bounding sphere, and at least 6 m. The height is in metres above EVE's feet, and a
  negative one lowers the mesh; `auto`, the default, lifts the mesh until its lowest point is 5 m above her feet. The
  two `auto` values use the bounds stored in the mesh asset, times the scale. When those cannot be read, the mesh goes
  6 m ahead, with the point it stands on 5 m up. The log line
  `show body: bounding sphere radius 50 m, centre 30 m and lowest point -2 m above its root` gives the radius, and the
  heights of the mesh's middle and of its lowest point above the point it stands on. The scale goes from 0.01 to 100,
  1 by default. A number first is a distance for the body: `coop leviathan show 40 15` shows the body 40 m away and
  15 m up. The mesh plays each animation made for its skeleton twice, one after another, and starts over after the
  last, with a log line for each. A blend space plays at input 0, 3 s twice. A second `show` replaces the first and
  keeps the last skin. It runs only on a [co-op save](#co-op-saves).
- `coop leviathan move <distance m>|auto [<height m>|auto]` puts the shown mesh that far in front of where EVE stands
  now, facing her, at that height. `auto` works as for `show`, and a missing height is `auto`. It is the same mesh,
  with its animation, scale and skin: walk EVE to another spot, then move it there.
- `coop leviathan skin statue|hydra|default` sets every material slot of the shown mesh to one material. The
  Leviathan's only material, `Default` in its folder, is a grey placeholder. `statue` is the secret room statue's
  material (`C_Reviathan_MI`), `hydra` the Hydra's tentacle material (`MI_M_NA_09_V03_Tentacle`), and `default` puts
  the mesh's own materials back. The skin stays through `play` and `move`, and the next `show` uses it. The log line
  gives the number of slots set.
- `coop leviathan play <name>` holds one animation of the shown mesh in a loop, for screenshots. The name is matched
  in any case against the end of the animation names, then anywhere in them: `coop leviathan play lightningball` plays
  `M_Leviathan_LightningBall1_1`. `coop leviathan play` alone goes back to the cycle. Both turn the free camera on.
- `coop leviathan off` removes the mesh and turns the free camera off. `coop off`, a map change and its first error
  remove it too. While it is shown, `coop-leviathan.txt` holds its path, so the next Lua load (Ctrl+R) removes it if
  this one could not. The next `show` tries again first, and shows nothing new while the old mesh cannot be removed.

`coop gardener` and `coop tendril` differ in these points:

- `show` has one mesh, `body`: `CH_M_NA_01` for the Gardener, `CH_M_NA_06_test` for the Tendril. Its `auto` height
  puts the mesh's lowest point at EVE's feet, since both stand on the ground, and its root at her feet when the bounds
  cannot be read. At scale 1, `auto` puts the Gardener about 23 m away and the Tendril about 12 m away.
- `list` reads their own folders. For the Gardener: its mesh and skeleton, 29 animations and blend spaces, 4 Blueprint
  classes, its projectile class, the `M_Gardener_SingleShot_1`, `M_Gardener_MultipleShot_1` and `M_Gardener_ToxicBeam`
  shows from `/Game/Art/Show/CH_M_NA_01_Gardener/Skill/` and `Default` in its folder. Its CharacterTable rows are those
  that contain `NA_01` or `Gardener`. For the Tendril: its mesh, skeleton, 44 animations and blend spaces, 2 Blueprint
  classes and its physics asset, and the rows that contain `NA_06` or `Tendril`. No row of the game's CharacterTable
  contains any of these words (read offline on 2026-10-23), so both lists report 0 rows.
- `play` matches their own animation names: `coop gardener play toxic_beam` plays `Mon_Gardener_S_03_Toxic_Beam`,
  `coop gardener play hide` plays `Mon_Gardener_C_Hide` and `coop gardener play unhide` plays `Mon_Gardener_C_UnHide`.
  `coop tendril play whipattack` plays `M_Tendril_WhipAttack`; its left and right versions need their `_l` or `_r`.
- `skin`: the Gardener has only `default`, its own textures. The Tendril has `hydra` and `default`. Its `default` is the
  engine's grey, since its one material slot is empty. Each creature keeps its own last skin for its next `show`.
- `move`, `skin` and `play` act on the shown mesh only when it is that command's creature: with the Gardener shown,
  `coop tendril move 20` answers `no Tendril is shown: coop tendril show first`. `off` of any of the viewer commands
  removes the shown mesh, whichever it is, and turns the free camera off.

#### Other cut models: `coop mann`, `coop nier`, `coop orcal` and `coop enya`

Four more test commands use the same viewer, words and free camera for cut models that are not Naytibas. None of them
has been tried in game yet.

| Command | `show` words | What it shows |
| --- | --- | --- |
| `coop mann` | `body` | The early Mann, `CH_NPC_Mann` in `/Game/Art/Character/NPC/Mann/`, about 3.5 m tall, with his 4 animations: 3 idles and a run. The shipped Mann uses another mesh, `CH_NPC_Mann_Body` in `CH_NPC_Mann_01/`. |
| `coop nier` | `square` (the default), `squareb`, `cylinder`, `cylinderb`, `cylinderc`, `sphere`, `sphereb` | The NieR collaboration's three cut machines, `CH_M_NA_951` to `CH_M_NA_953` in `/Game/DLC_1/Art/Character/Monster/`, with their TypeB and TypeC variants: blockout shapes of 32 to 810 vertices with no material, drawn in the engine's grey |
| `coop orcal` | `test1` (the default), `test2`, `native`, `preview` | Orcal prototypes in `/Game/Art/Character/NPC/CH_NPC_XionElder/`: `OrcalTest_01`, `OrcalTest_02` (both about 1 m tall), `XionElder_Native_Preview` and `PreviewMesh/CH_NPC_XE_testmesh` (1.8 m tall and 3.7 m wide) |
| `coop enya` | `mech` (the default), `enya05` | Enya prototypes in `/Game/Art/Character/NPC/CH_NPC_Enya/Temp/`: `CH_NPC_Enya_Mech` and `Enya_05`, 1.6 and 1.7 m tall |

- Only the early Mann plays animations. The NieR machines have none: their blend spaces hold no samples, so `list`
  reads them as `list asset` lines and nothing plays them. The Orcal and Enya meshes have one bone each, in a fixed
  pose. `CH_NPC_XE_testmesh` names no skeleton in its file, so the engine draws it in its reference pose and `list`
  reads `skeleton=-` for it.
- `auto` puts each model's lowest point at EVE's feet, 1.6 times its bounding sphere radius away and at least 6 m
  (3 m for the Orcal and Enya statues).
- `skin` takes `default` only.
- `list` reads each command's meshes, skeletons, Blueprint classes and physics assets (the NieR blend spaces too), then
  the CharacterTable rows that contain `CH_NPC_Mann_Blueprint`, `NA_95`, `OrcalTest`, `Enya_Mech` or `Enya_05`. A
  plain `Mann` would match the shipped Mann's rows.

#### Free camera

The free camera is for filming the mesh. `show` and `play` turn it on, and `coop leviathan cam` turns it on or off
(`cam` of the other viewer commands does the same with the same camera).
Turning it on needs a co-op save, like `show`; turning it off works on any save. It starts where the game's camera is
and blends there in 0.3 s. EVE keeps standing where she was: while the camera is on, the game ignores the move input
of her controller. Its look input stays on, and the free camera turns with the controller, so the mouse and a
controller's right stick turn it as they turn the game's own camera, with your sensitivity settings. The camera stays off when `coop-leviathan.txt` cannot be written, since the next Lua load
could not give the controller back without it.

| Key | Free camera |
| --- | --- |
| W or Z | Forward, where the camera looks |
| S | Back |
| A or Q | Left |
| D | Right |
| Space or E | Up |
| Left Ctrl or C | Down |
| Left Shift, held | 4 times as fast |
| Mouse or right stick, and the arrow keys | Turn |

The keys cover QWERTY and AZERTY. The speed is 10 m/s; `coop leviathan cam <m/s>` sets another one, from 0.1 to 500,
until the next Lua load. The arrow keys add 90 degrees a second to the turn. If the controller's rotation cannot be
read, the log says so once and only the arrow keys turn the camera.
No key moves the camera while the co-op menu, the chat box or another co-op box is open.

The game's HUD stays on screen: hide it in the game's own settings before you film. Only walking is blocked, so a key
the game binds to another action (an attack on the left mouse button, for example) still reaches EVE where she stands,
and the game's camera turns behind the free one: back on EVE, it looks where you last looked.

`coop leviathan cam` again, `coop leviathan off`, `coop off`, a map change and the camera's first error turn it off.
The view goes back to what it showed before the camera turned on: EVE, or a fixed camera of the game's, and EVE when
that camera is gone. If the game moved the view to another camera meanwhile (a dialogue), the view stays there. Her
controller ignores move and look input again only if it did before, and the camera is removed. While it is on,
`coop-leviathan.txt` also holds the camera's path, the player controller's and the view's from before, so the next Lua
load (Ctrl+R) does the same if this one could not.

### Cut boss: `coop lion`

The game's files hold a boss that was cut before release: Naytiba 02, the Lion, in
`/Game/Art/Character/Monster/CH_M_NA_02/`. Its blueprint, meshes, animations, hit data and skill presentations (Shows)
ship, but no table row names it, so the game cannot spawn it. `coop lion` adds the 222 rows it lacks to the game's
tables in memory and spawns it as an enemy to fight. The same batch starts with 4 rows for the cut stimpacks of the
[reward shop](night-operation.md#the-reward-shop) and 11 for EVE's [cut ChainSpin](#cut-tachy-skill-coop-chainspin),
237 rows in 14 tables, and a buy of a stimpack, the shop screen or `coop chainspin` asks for it as `coop lion rows`
does. The cut [Shock Bolt](#cut-ammo-shock-bolt) ammo's 4 rows are a batch of their own that only the shop asks for: a
Shock Bolt buy, and `coop nightop shop` (or Roxanne's supplies choice) before it opens the shop screen. Every row of
the Lion's is written for it: its stats, its skills, the timing of its hits and the moves that follow its own
animations. It is a test command, left out of the usage line. Its lines go to `UE4SS.log` as `[StellarCoop][LI]`; the
native part's go to `coop-link.log` as `lion rows ...`.

- `coop lion` spawns a Lion 10 m in front of EVE and 1 m up, facing her. The first time in a game run it asks the native
  part to add the rows and waits for the answer, 30 s at most. Each time it reads every row back first and stops at the
  first value that differs, with no spawn. It runs only on a [co-op save](#co-op-saves).
- `coop lion intro` first plays the Lion's entrance from the cut boss intro (`Mon_LionC_Scene01_Appearance`, 13 s) on a
  copy of its mesh where it will stand, then spawns the Lion where the copy's root ended (at the 10 m spot when that is
  more than 20 m away) and removes the copy as soon as the Lion is there. The copy is a display only, like the Doros of
  a race: it cannot fight or be hit. A copy that cannot be made skips the entrance and spawns at once. A map change
  during the entrance spawns nothing. Co-op save only.
- `coop lion rows` adds the rows (the Lion's, the stimpacks' and the ChainSpin's) and reads them back, with no spawn.
  Any save.
- `coop lion control` spawns an Antlion (M_Antlion, 50110), a shipped Naytiba, through the same call and with no rows.
  If the Antlion comes and the Lion does not, the rows are at fault rather than the call. Co-op save only. The native
  part reads the game's spawn counter only once rows were asked in the game run, so run `coop lion rows` first if the
  Antlion's lines should carry it; before that they show `spawn count ?`.
- `coop lion brain skulling|lurker` picks the behaviour tree of the next Lions until the mod reloads. `skulling`, the
  default, spawns 50020 (row M_LionC, tree M_Skulling_AI_Test); `lurker` spawns 50021 (row M_LionC_Lurker, the Lesser
  Lurker's tree). Any save.
- `coop lion unfreeze` sets, on each living Lion, every engine switch that can keep a mesh's pose still back to its
  running value: the mesh's tick, its animation pause, its rate scale, its skeleton updates, its visibility-based and
  rate-optimized ticking and the actor's time dilation. It then logs the mesh line again. `coop lion unfreeze init`
  also builds the Lion's animation instance again (`SetAnimInstanceClass` with its own class). The game's skills may
  not survive that, so try it last. Any save.

While a command waits for its rows, its body or its entrance, another `coop lion` answers that it is busy.

Try it in an open, flat area such as the Great Desert, with open ground 10 m in front of EVE, away from story events,
quest areas and Behemoths.

What to expect:

- The Lion has 160000 HP, 3300 shield and 14 stamina, and attacks with a power of 960. That is a little under the Great
  Desert bosses (170500 HP, 3500 shield, 15 stamina). On Story mode it has 10% less HP and 30% less attack; on Hard
  mode, 150% more HP, shield and attack. Its rank is Elite, and it is a boss to the game, so the boss bar shows once it
  targets EVE. The game has no name text for it and writes `<M_LionC>` on the bar; while a Lion lives, `coop lion`
  changes that to `Lion` (checked once a second, since the game writes the name again at each boss bind).
- It has 21 skills, each one playing one of its own skill animations: two claws, two chasing claws, two turning
  attacks, two running attacks, two jumping attacks, two back jumps, a roar, two side steps, a three-claw chain and a
  rush. Under 60% HP it switches to its second phase, which adds a four-claw chain, a chain of claws on the move, a
  chain of four pounces, and a roar at the switch. Both trees pick the skills flagged MeleeAttack, which leaves out the
  side steps and the switch's roar (the switch itself starts that one). Whether the game plays that roar is not known
  yet; the phase switch itself is how the game's Raven fight works.
- Each attack hits during the part of its animation where the claw, paw or jaw swings, measured on the animation
  itself. The roars and the high jump cannot be parried or blocked, only dodged; the other attacks can be parried,
  blocked and perfect-parried.
- Each move follows its animation: the Lion travels as far as its feet show, when they show it. A move toward EVE
  stops short of her, where the next blow lands, so a leap does not carry the Lion past her when she stands closer than
  the leap's length. A skill that leaps before its first blow starts only when EVE stands at least 30 cm past where
  that leap stops (8.3 m for the high jump, 1.8 m for the low jump), so the Lion does not back off before it strikes.
  The two claw chains and the dash chain would have no range left that way: their first steps go up to EVE instead.
  Leaps are estimates, since the feet are off the ground. The two running attacks and one chasing
  claw look for EVE to the side and keep the Lion's heading; the other skills turn it toward her. Each skill's range is
  the reach of its first hit toward EVE plus what its moves close before it, and a skill whose moves take the Lion 3 m
  or more one way needs that much open ground to start. It walks at 2 m/s and runs at 9 m/s, the Behemoth's pace. Its
  run animation, at the Lion's size, strides faster than that, so its feet may slide.
- EVE's link attack on it plays the generic link: the Lion reacts with its own `Hit_Sword_Normal_LinkAttack1` clip.
  When its balance gauge empties it goes groggy as Stalker and Abaddon do, with their one-second delay before EVE can
  link.
- Its rows give it its own death animation (7 s), then a dissolve (15 s). It drops nothing.
- It should not come back from a save: a Lion alive when you load a save or change maps is gone. No command removes one:
  it goes when it dies or with the map.
- No quest event runs for it. A kill counts toward the two achievement counters that take any enemy, as any Naytiba kill
  does. It unlocks no album entry.
- The rows stay in memory until the game exits. A second `coop lion` only reads them back. Nothing is written to a game
  file or a save.
- Only your game has the Lion. In a session your friend does not see it, and her ghost on your screen is no target for
  it. If she types `coop lion`, she gets her own Lion in her game.

The entrance is off by default because the Lion's animation blueprint has no montage slot: a montage played on it would
not show; a clip played straight on its mesh would replace the animation instance that the game plays the Lion's skills
on while its AI runs.

The log lines, in `UE4SS.log` unless marked:

| Line | What it answers |
| --- | --- |
| `tables: 19/19 found: CharacterTable=0x...` | The 19 tables found, with the addresses sent to the native part |
| `lion rows: 237/237 added through SB's AddRow 0x14417ba30, 0 refused` (`coop-link.log`) | The native part added every row |
| `lion rows by SB's lookups: CharacterTable 50020-50021 2/2, SkillTable 1004500-6000101 23/23, stance 500200-500201 2/2` (`coop-link.log`) | The game's own lookups by ID find the rows, which the spawn and the skills need (SkillTable: the Lion's 21 skills, the stimpacks' skill, 6000101, and the ChainSpin, 1004500) |
| `rows read back through FindRow: 237/237 authored rows, 3178 fields as written (2156 differ from the template row)` | Every field the native part wrote reads as written; 2156 of them hold a value the shipped row it started from did not, and the other 1022 restate that row's value |
| `rows already in (237/237; ...): not added again` | A later `coop lion` in the same game run |
| `spawn 50020: CreateActor returned; body CH_M_NA_02_BluePrint_Large_C 9.8 m from EVE, ...; controller SBAIController; EventSpawnId 0` | The body is in the world, with its controller and its spawn key (0) |
| `lion 1 (50020): 3.1 m, xyz 40764,-12702,-19058, speed 0, skill yes, anim alpha 0.00/0.00, hand moved 0 cm, battle 1, state 1, controller yes, spawn count -5, frame 16.7 ms (worst 24.1), lion Lua 0.4 ms/s, longest tick 0.3 ms (last pass: follow 0.2 ms, boss name 0.0 ms)` | Once a second while it lives: its distance to EVE, where it stands, the speed its walk animation reads (cm/s), whether a skill runs, how much of a skill's clip its animation blueprint shows (0 to 1, two layers), how far its left front paw (`Bip001-L-Hand`) moved in its own frame since the last line (0 cm while it runs or attacks: its pose does not play), battle mode, state, controller, the game's spawn counter, and over the last second the mean and worst frame time, the time this file's tick took and its longest single tick (to tell the Lion's cost from the mod's: a longest tick near the worst frame is the mod's), and what the last once-a-second pass took by part |
| `before the spawn: frame 16.4 ms (worst 19.0), lion Lua 0.1 ms/s, longest tick 0.1 ms (last pass: none yet)` | The same frame part while the command waited, before the Lion was there: compare it with the follow lines |
| `lion 1 (50020) mesh: anim instance CH_M_NA_02_AnimBP_C, anim class CH_M_NA_02_AnimBP_C, its skeleton CH_M_NA_46_Skeleton, mesh skeleton CH_M_NA_46_Skeleton, mode 0, leader none, anim set sync true, mesh CH_M_NA_02_Large, tick true, pause false, rate 1.0, no skeleton update false, visibility tick 0, rate optimizations true, actor dilation 1.0, sequencer anim mode false` | Its mesh as the engine ticks it, before its first line and at each change: the animation instance class (`none` when it has none), the mesh's anim class, that class's target skeleton, the mesh's skeleton, its animation mode (0: animation blueprint, 1: single node), the component it copies its pose from (`MasterPoseComponent`), SB's `bInitAnimSetSyncData` (the character's animation set read), its mesh asset, the mesh's tick, `bPauseAnims`, `GlobalAnimRateScale`, `bNoSkeletonUpdate`, `VisibilityBasedAnimTickOption`, `bEnableUpdateRateOptimizations`, the actor's `CustomTimeDilation` and SB's `bSequencerAnimMode`; `?` for a field that does not read |
| `lion 1 (50020) had no anim instance: its own class built none, ...; stand-in: the single-node instance plays IdleRun_BS_ by speed; mesh: ...` | When no AnimBP builds one: the engine's single-node instance loops the Lion's battle idle-run blend space, its speed input set each frame from the anim graph speed (600 cm/s at most), so the Lion stands, walks and runs. Its skills play no clip with it |
| `...; leader: the Lion AnimBP runs on a hidden CH_M_NA_46, the Lion mesh copies its pose; mesh: ...` | When no AnimBP builds an instance on the Lion's mesh: the body's mesh component takes the Behemoth's mesh (whose bones hang as the skeleton's do) with the Lion's AnimBP, drawn in no pass (no main pass, depth or shadow) so the engine still ticks it, and a new component draws the Lion's mesh and copies that pose bone by bone. SB's skills and moves then play as on any monster. If that fails too, the Lion gets its mesh back and the stand-in plays |
| `lion 2 (50110) rebuild test: its own class built one; mesh: ...` | The control Antlion's first line: its instance rebuilt with its own class (written into `AnimClass`, mode 1 then 0), which says whether that rebuild works on a shipped Naytiba's body |
| `entrance copy AnimBP test: its own class built none, CH_M_NA_02_AnimBP_C built one` | `coop lion intro`, before the spawn: the same tries on the entrance copy, a plain actor's mesh rather than an SBCharacter's. An instance there means the Lion's AnimBP is sound and the Lion's body refuses it |
| `lion 1 (50020) had no anim instance: its own class built none, CH_M_NA_02_AnimBP_C built one; mesh: ...` | Its mesh had no animation instance. Once a body (never for the control Antlion), the mod asks the engine to build one: with the mesh's own anim class, then the Lion's AnimBP, then the Behemoth's (same skeleton), each class found by its path, written into the mesh's `AnimClass` and followed by a switch to single-node mode and back. The line says what each try gave, then the mesh line |
| `lion 1 (50020) unfreeze: tick, pause, rate, skeleton, visibility, optimizations, dilation; mesh: ...` | What `coop lion unfreeze` set (a failed one with its reason) and the mesh line after it |
| `boss name: <M_LionC> -> Lion` | The boss bar's name set to Lion |
| `lion 1 (50020) recycled: SB moved its body back for this spawn` | The game reused a Lion body it had sent far away for the next spawn; that spawn's line ends with `a body SB reused` |
| `lion 1 (50020) dead after 143 s (InteractionState 3, no controller); body gone after 22.4 s` | Its death and its body's despawn |
| `lion 1 spawn count: before 6, alive 7, after death 6` | The game's spawn counter before the spawn, while it lived and after |
| `entrance: ...` | What `coop lion intro` played, or why the entrance was skipped |

A refusal names its reason in `coop-link.log` (`lion rows refused <row>: <why>; <n>/237 added`) and ends with a `STOP:`
line in `UE4SS.log`. Asking again skips the rows already added. Ask in a loaded save: on the title screen the native
part can wait for a game state that never comes and refuse after 300 frames. See
[how-it-works.md](how-it-works.md#the-cut-lion) for how the rows go in.

In the tests of 2026-10-23 and 2026-10-24 the Lion fought like a boss, but its body stayed on the first frame of its
idle pose: its mesh had no animation instance. The cause: the Lion's three meshes hang the `Bip001` bone under `Root`,
while the skeleton they share with the Behemoth (`CH_M_NA_46_Skeleton`) hangs it under a `Base` bone added later. UE
4.26 builds an animation blueprint's instance only for a mesh whose bones match its skeleton's hierarchy, so neither the
Lion's AnimBP nor the Behemoth's ran on any Lion mesh, while the single-node instance (the entrance, the stand-in) has
no such check. `coop lion` now runs the Lion's AnimBP on a hidden Behemoth mesh and draws the Lion's mesh on top,
copying its pose bone by bone, so its skills and moves animate through the game's own system.

### Cut enemy: `coop gardener fight`

The Gardener, Naytiba 1 of the [viewer](#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril), was cut
with its fight. The game still ships its blueprint, its skill presentations (Shows), its shells, its appearance, death
and detection rows and a whole skill kit, but no CharacterTable row and no behaviour tree, so it cannot spawn.
`coop gardener fight` adds the 13 rows it lacks to the game's tables in memory, as a batch of their own next to the
[Lion's](#cut-boss-coop-lion), and spawns it as an enemy to fight. Each row is a copy of a shipped one with a few
fields changed. It is a test command, left out of the usage line. Its lines go to `UE4SS.log` as `[StellarCoop][GD]`;
the native part's go to `coop-link.log` as `gardener rows ...`.

- `coop gardener fight` spawns the Gardener (row `M_Gardener`, 50010) 25 m in front of EVE and 7.5 m above her feet,
  facing her. The first time in a game run it asks the native part to add the rows and waits for the answer, 30 s at
  most. Each time it reads the 13 rows back first and stops at the first value that differs, with no spawn. It runs
  only on a [co-op save](#co-op-saves).
- `coop gardener fight half` spawns `M_Gardener_Half` (50012), the same at half size, 12.5 m away. Co-op save only.
- `coop gardener fight skulling` spawns `M_Gardener_Skulling` (50011), which runs the Lion's tree
  (`M_Skulling_AI_Test`) instead of `M_Tentacle_AI`. Try it if the default Gardener never attacks. Co-op save only.
- `coop gardener fight intro` first plays `Mon_Gardener_C_Appear` (15.5 s) on a copy of its mesh where it will stand,
  then spawns the Gardener there and removes the copy as soon as the body is there. `coop gardener show` then
  `coop gardener play appear` or `coop gardener play spawn` previews the spawn animations in the viewer. Co-op save
  only.
- `coop gardener fight rows` adds the rows and reads them back, with no spawn. Any save.

The words that spawn first put away a viewer display and the free camera, so the viewer's model and the Gardener never
stand in the same place. While a command waits for its rows, its body or its entrance, another `coop gardener fight`
answers that it is busy. Every other `coop gardener` word is the viewer's.

Try it on open, flat ground with 30 m clear in front of EVE and no Naytiba within 50 m: each shell kills any Naytiba
within 2.3 m of where it lands.

What to expect:

- It is about 20 m tall and never walks: its stance moves at 0 cm/s, and it turns toward EVE at 100 degrees a second,
  and in 0.3 s at the start of each attack. Its skeleton faces sideways compared with the game's monsters, so the mod
  turns its mesh by 90 degrees once it spawns, and again if the game turns it back.
- It has 37840 HP and 1455 shield (the Behemoth's) and attacks with a power of 930. Its rank is Elite and it is a boss
  to the game, so the boss bar shows once it targets EVE, with the game's own name text for it (the album's
  `Char_M_Gardener_AlbumName`, most likely "Gardener" in English).
- It has three attacks, all shells fired from its mouth: SingleShot (shells on EVE and up to 3 m around her, then 15 and
  18 m ahead of her), MultipleShot (three volleys, every 10 s at most) and ToxicBeam (its beam animation, then 8 shells
  from EVE out to 15 m ahead of her within 0.7 s, every 15 s at most). No beam is drawn: the game ships no effect for
  it. A shell marks where it will land 2 s before, explodes for 100 HP within 2.3 m and leaves a poison zone for 5 s (30
  HP a second), before difficulty.
- Its tree, `M_Tentacle_AI`, was made for monsters that stay put. It may play the Tentacle's 1 s battle-start animation
  once a fight, which the Gardener's skeleton lacks: nothing shows, or a wrong pose for 1 s.
- It never staggers, falls or goes groggy (it has no animations for them) and has no weak point.
- At full size only its right foot is at sword height; the blaster reaches its body. At half size its legs come lower
  if the game scales its hit boxes with its mesh, which is not checked yet.
- When it dies it keeps its last pose (it has no physics for a ragdoll), then dissolves as the Cocoon does. It drops
  nothing.
- As for the Lion: no quest event runs for it, it unlocks no album entry, it should not come back from a save, the rows
  stay in memory until the game exits, and only your game has it.

The log lines, in `UE4SS.log` unless marked:

| Line | What it answers |
| --- | --- |
| `tables: 19/19 found: CharacterTable=0x...` | The 19 tables found, with the addresses sent to the native part |
| `gardener rows: 13/13 added through SB's AddRow 0x14417ba30, 0 refused` (`coop-link.log`) | The native part added every row |
| `gardener rows by SB's lookups: CharacterTable 50010-50012 3/3, SkillTable 5001010-5001012 3/3, stance 500101 1/1` (`coop-link.log`) | The game's own lookups by ID find its three CharacterTable rows, its three skills and its stance |
| `rows read back through FindRow: 13/13 authored rows, 279 fields as written (102 differ from the template row)` | Every field the native part wrote reads as written |
| `rows already in (13/13; ...): not added again` | A later `coop gardener fight` in the same game run |
| `spawn 50010: CreateActor returned; body CH_M_NA_01_BluePrint_C 25.9 m from EVE, ...; controller SBAIController; EventSpawnId 0` | The body is in the world, with its controller and its spawn key (0) |
| `gardener 1: mesh yaw set to -90 (was 0)` | Its mesh turned to face EVE, or why the call failed |
| `gardener 1 (50010): mesh yaw 0, not -90 (the game turned it back): set again` | The game turned the mesh back, and the mod turned it again |
| `gardener 1 (50010): 25.9 m, xyz ..., speed 0, skill yes, ...` | Once a second while it lives, the same fields as the Lion's line |
| `gardener 1 (50010) dead after 210 s (InteractionState 3, no controller); body gone after 16.0 s` | Its death and its body's despawn |
| `gardener 1 spawn count: before 6, alive 7, after death 6` | The game's spawn counter before the spawn, while it lived and after |

A refusal names its reason in `coop-link.log` (`gardener rows refused <row>: <why>; <n>/13 added`) and ends with a
`STOP:` line in `UE4SS.log`. A refusal of the Gardener's rows leaves the Lion's batch alone, and the other way round.
See [how-it-works.md](how-it-works.md#the-cut-gardener) for how the rows are made.

### Cut enemy: `coop tendril fight`

The Tendril, Naytiba 6 of the [viewer](#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril), was cut
early. Its files keep a test mesh with no material, a blueprint, an animation blueprint and 42 animations, but no table
row and no skill presentation (Show) for any of them. `coop tendril fight` adds the 107 rows it needs to the game's
tables in memory, as a batch of their own next to the [Lion's](#cut-boss-coop-lion) and the
[Gardener's](#cut-enemy-coop-gardener-fight), builds the 12 Shows its attacks and its death play, also in memory, and
spawns it as an enemy to fight. It is a test command, left out of the usage line, and it has not run in game yet. Its
lines go to `UE4SS.log` as `[StellarCoop][TD]`; the native part's go to `coop-link.log` as `tendril rows ...`.

- `coop tendril fight` spawns the Tendril (row `M_TendrilC`, 50060) 8 m in front of EVE, facing her. The first time in a
  game run it asks the native part to add the rows and waits for the answer, 30 s at most. Each time it reads the 107
  rows back and builds the Shows first, and a value that differs or a Show it cannot build stops it with no spawn. It
  runs only on a [co-op save](#co-op-saves).
- `coop tendril fight rows` adds the rows, reads them back and builds the Shows, with no spawn. Any save.

The spawn first puts away a viewer display and the free camera. While a command waits for its rows or its body, another
`coop tendril fight` answers that it is busy. Every other `coop tendril` word is the viewer's.

What to expect:

- It walks on its hands and feet, its head about 1.4 m up, and strikes with the four chains on its head. Its skeleton
  faces sideways compared with its blueprint, so the mod turns its mesh by 90 degrees once it spawns (and again if the
  game turns it back), and gives it the Hydra's tentacle material, as `coop tendril skin hydra` does in the viewer.
- It has 64960 HP, 3720 shield and an attack power of 600 (the Gigas's numbers) and rank Boss, so the boss bar shows
  once it targets EVE. The game has no text for its name and shows `<M_TendrilC>`; the mod writes `Tendril` there.
- It has 11 attacks, each one of its own animations: two sweeps, two lashes and two diagonal swings with one chain, a
  chop with both chains that lands 6.6 m ahead, a spin, and three combos (Rush, four hits, the last two slamming down
  5.8 and 7.5 m ahead; Whip, three hits; Trace, two). Each hit strikes anyone in an arc in front of it, 4 to 7.5 m
  deep, while its chains strike. Guard, parry and perfect parry work on every hit, as on the Lion.
- It walks at 2 m/s, runs at 4 m/s and turns toward EVE at the start of each attack.
- EVE's hits play its knock-back animation. It never goes groggy, falls or flies: the game's animation sets for those
  states name animations it does not have.
- When it dies it plays its death animation (6 s), then dissolves as the Cocoon does. It drops nothing.
- As for the Lion: no quest event runs for it, it unlocks no album entry, it should not come back from a save, the rows
  and the Shows stay in memory until the game exits, and only your game has it.

The log lines, in `UE4SS.log` unless marked:

| Line | What it answers |
| --- | --- |
| `tables: 19/19 found: CharacterTable=0x...` | The 19 tables found, with the addresses sent to the native part |
| `tendril rows: 107/107 added through SB's AddRow 0x14417ba30, 0 refused` (`coop-link.log`) | The native part added every row |
| `tendril rows by SB's lookups: CharacterTable 50060 1/1, SkillTable 5006000-5006010 11/11, stance 500600 1/1` (`coop-link.log`) | The game's own lookups by ID find its CharacterTable row, its 11 skills and its stance |
| `rows read back through FindRow: 107/107 authored rows, 1281 fields as written (997 differ from the template row)` | Every field the native part wrote reads as written |
| `shows: 12/12 ready (12 made, 0 found built), each with its own anim key on its clip and found by the path its steps name` | The Shows are built and the game can find them; after a Lua reload, `0 made, 12 found built` |
| `not ready: M_TendrilC_SwingLeft: no anim key of its own: no spawn` | A Show (or its package, `/Game/Art/Show/StellarCoop/Tendril`) could not be built, and why |
| `spawn 50060: CreateActor returned; body CH_M_NA_06_Blueprint_C 8.1 m from EVE, ...; controller SBAIController; EventSpawnId 0` | The body is in the world, with its controller and its spawn key (0) |
| `tendril 1: mesh yaw set to 0 (was -90)` | Its mesh turned to face its front |
| `tendril 1: material MI_M_NA_09_V03_Tentacle on its 1 slots` | The Hydra's material on its mesh, or why not |
| `boss name: <M_TendrilC> -> Tendril` | The boss bar's name set |
| `shows: M_TendrilC_Chop gone: built again` | The game dropped a Show while the Tendril lived, and the mod built it again |
| `tendril 1 (50060): 8.1 m, xyz ..., speed 0, skill yes, anim alpha 1.00/0.00, ...` | Once a second while it lives, the same fields as the Lion's line; `anim alpha` above 0 while a skill runs means its animation plays |
| `tendril 1 (50060) dead after 95 s (InteractionState 3, no controller); body gone after 22.0 s` | Its death and its body's despawn |
| `tendril 1 spawn count: before 6, alive 7, after death 6` | The game's spawn counter before the spawn, while it lived and after |

A refusal names its reason in `coop-link.log` (`tendril rows refused <row>: <why>; <n>/107 added`) and ends with a
`STOP:` line in `UE4SS.log`. A refusal of one batch leaves the others alone. See
[how-it-works.md](how-it-works.md#the-cut-tendril) for how the rows and the Shows are made.

### Cut Tachy skill: `coop chainspin`

The game's files hold a Tachy Mode skill for EVE that was cut before release, the ChainSpin: her animation
`P_Eve_Tachy_Skill_ChainSpin1` with its root motion, a wing animation, two move rows
(`P_Eve_Tachy_Skill_ChainSpin1_Move1` and `_Move2`) and the skill icon `SI_TachyMode_ChainSpin1`. No skill row, step or
skill presentation (Show) of EVE's uses them, so no button plays it. The prologue's Tachy NPC kept a version: its skill
`N_TachyNPC_SwingChain` plays the Show `CH_NPC_TachyNPC/Skill/N_TachyNPC_SwingChain`, which plays EVE's own ChainSpin
animation (3.25 s, nine steps) and takes the two moves.

`coop chainspin` adds EVE's version to the game's tables in memory with the [cut Lion's rows](#cut-boss-coop-lion) (11
of the 237: the skill `P_Eve_Tachy_Skill_ChainSpin1_1`, its nine steps and an effect), then asks the game to apply that
effect on EVE. The effect starts the skill only while she is in Tachy Mode; outside it, nothing happens. It is a test
command, left out of the usage line, and runs only on a [co-op save](#co-op-saves). Its lines go to `UE4SS.log` as
`[StellarCoop][CS]`.

- The steps are copies of ChainStab's, the first of EVE's four Tachy skills, with the Tachy NPC's timing and moves. Its
  four hits strike through the same weapon and arm collision as ChainStab, within 10 m of her, each for a quarter of
  the skill's damage; the last one stuns for 1.5 s.
- The request is the game's own cheat request, `SBApplyEffectMe` with the effect's ID (1004500), which the game runs as
  a logic job on EVE. It goes out once the rows are in (the first time in a game run it waits for them, 30 s at most),
  and never while a respawn or a warp is under way.
- No button starts it. EVE's four Tachy skill buttons are taken, and a fifth would mean replacing the Tachy stance row
  while EVE uses it.
- Nothing is saved: the skill has no skill tree entry, slot or achievement tag, and the rows stay in memory until the
  game exits.
- The Tachy NPC's Show plays no wing animation, so EVE's Tachy wings keep their own pose during the spin. The game has
  no name, description or preview video for the skill.
- Only your game runs it. What your friend sees of it in a session is untested.

| Line | What it answers |
| --- | --- |
| `ChainSpin asked: SBApplyEffectMe 1004500 on EVE (guid 228)` | The request went out, for EVE's GUID |
| `ChainSpin waits for its rows (...)` | The rows were asked of the native part; the request follows once they are in, and its result comes as an `OK:` or `STOP:` line then |
| `ChainSpin: its rows are not in (...)` | The rows could not be added: nothing was asked |
| `ChainSpin request failed: ...` | The game call raised: nothing was asked |

None of it has been tried in game yet. Check that EVE plays the spin in Tachy Mode and nothing outside it, that she
travels with its two moves (7.5 m, then 2.9 m), that its four hits land on enemies around her, and that the game keeps
running normally after it.

### Cut ammo: Shock Bolt

The game's files hold a third ammo for EVE's gun that was cut before release, the Shock Bolt. A hit stuns a common enemy
for 10 s, or until it is hit again (the game's own stun effect, `ShockSlugStun`, which does nothing to animals, elites
and bosses). Its fire commands, steps, consumable, projectile blueprint and stun ship, but it has no item, skill,
projectile or hit result row, EVE's gun stances list only its failed shot, and the ammo selector stops at five types.

The [reward shop](night-operation.md#the-reward-shop) sells it as item 7, 5 points a bolt: `coop nightop buy 7 10`, or
on the shop screen of `coop nightop shop`. The buy (or the screen) gets the Shock Bolt's 4 rows in first, a batch of
their own (`bolt rows`), apart from the
[cut Lion's rows](#cut-boss-coop-lion). In the same frame as the last of the 4, the native part adds the two fire
commands the game ships (`P_Eve_Gun_ShootShockSlug1_1` and `_1_2`) to EVE's gun stances and `Bullet_Shock` as a sixth
entry of the game's ammo list, without replacing a row (see [how-it-works.md](how-it-works.md#the-cut-shock-bolt)).
The buy goes through only when that worked, and the screen sells the Shock Bolt only then. Nothing else adds these
rows or the sixth slot: `coop lion`, `coop chainspin` and the stimpack buys leave EVE's gun as the game ships it.

- EVE carries 30 bolts at most. A shot takes one, and the next shot waits 1.5 s. The game adds bolts only up to 30
  and drops the rest, and the shop cannot read how many she holds, so the points of dropped bolts are not given back.
  Check her count before a buy.
- Aim to get the fire commands. If she was aiming when they went in, aim again.
- The ammo selector builds its list when the HUD starts. If the Shock Bolt does not show there, load a save and look
  again (when the HUD starts again is not known).
- The slot stays for the game run, with or without bolts. With none, the trigger should play the failed shot, as with
  the other ammo types.
- Every save keeps the bolts and the selected slot, the game's autosaves at a camp or a zone change included. After a
  restart the Shock Bolt's rows and the sixth slot are not in until the next Shock Bolt buy or `coop nightop shop`, so
  the save loads into a
  game without them, with the mod installed as without it. The readers of the selected slot found so far check it
  against their list's length, so slot 6 should read as no ammo, but the code that restores the slot from the save was
  not traced, and how the game loads bolts it has no row for is not known. Keep a backup of the co-op save, and switch
  to another ammo before you save or quit from the menu (which saves).
- Only your game has it. What your friend sees of a shot in a session is untested.

`coop-status.txt` has a `bolt=` line for the 4 rows, in the same forms as the `lion=` line (`bolt=rows added=4/4 ...`
once they are in), and a `shock=` line for the two lists: `shock=off` before, then
`shock=in commands=24,24 added=4 list=6 slots=6` (both stances' command counts, the commands added, the ammo list's and
the slot manager's entries; `slots=-` when the slot manager did not exist yet), or
`shock=refused why=<word> at=<where>`, with nothing written unless `why=alloc` (see the table below).

The log lines, in `UE4SS.log` (the shop's `[StellarCoop][NR]` lines) unless marked:

| Line | What it answers |
| --- | --- |
| `bolt rows: 4/4 added through SB's AddRow 0x14417ba30, 0 refused` (`coop-link.log`) | The native part added the 4 rows |
| `bolt rows by SB's lookups: CharacterTable - 0/0, SkillTable 1003401 1/1, stance - 0/0` (`coop-link.log`) | The game's own lookup by ID finds the Shock Bolt's skill |
| `[StellarCoop][LI] bolt rows read back through FindRow: 4/4 authored rows, 87 fields as written (22 differ from the template row)` | Every field the native part wrote reads as written |
| `bolt rows refused <row>: <why>; <n>/4 added` (`coop-link.log`) | A row the native part would not add, and why. The buy stops with no points taken, and the Lion's rows are not touched |
| `shock bolt in: 4 fire commands added (P_Eve_Gun 24 commands, P_Eve_GunBlockSword 24), BulletItemSlotArray grown, 6 entries, the slot manager's list grown, 6 entries` (`coop-link.log`) | Both stances and both ammo lists grew |
| `shock bolt refused at <where>: <why>; nothing written` (`coop-link.log`) | A check failed before any write: a stance row missing or with another ID, a list out of range, or an ammo list that is not the five the game ships |
| `shock bolt refused at <where>: SB's allocator gave nothing; the writes before it stay` (`coop-link.log`) | The game's allocator gave no memory partway through the writes (`why=alloc`). What went in before it stays: the fire commands appended, and the ammo list's sixth entry when `<where>` is `slots`. The shop sells no Shock Bolt |
| `shock bolt off: fault 0x... in ... reading 0x...; the rows stay, no Shock Bolt until the game restarts` (`coop-link.log`) | A fault in the native step. The rows and everything else keep running |
| `buy Bullet_Shock x10: the gun cannot fire it (shock=...); no points taken` | A buy refused because the `shock=` line does not say `in` |

None of it has been tried in game yet. Check that the Shock Bolt shows in the ammo selector with its icon and count,
that EVE fires it and the count drops, that a hit stuns a common enemy and not an elite, and that the game keeps running
normally after you switch ammo.

### Cut dungeon: `coop mxiii` (experimental)

The game's tables keep a dungeon that was cut before release, Matrix XIII (world `DLCMatrix13`), with four zones and
the enemies of each, but no pak holds its map and no camp or warp leads there. `coop mxiii` tests one way in. It needs
the zMXIII_P test pak, which does not come with the mod: a map at the path the game's world table names, built from
shipped Matrix 11 levels. Without that pak the command refuses and changes nothing. It is a test command, left out of
the usage line, and runs only alone (not in a session) on a [co-op save](#co-op-saves). Its lines go to `UE4SS.log` as
`[StellarCoop][MX]`, the travel's as `[StellarCoop][TR]`.

1. With the game closed, put `zMXIII_P.utoc`, `zMXIII_P.ucas` and `zMXIII_P.pak` in `SB/Content/Paks/~mods` (or
   `SB/Content/Paks/LogicMods`).
2. Load a co-op save you can lose. Entering a world the save has never been in may write that world, its zone and its
   enemies into the save; `coop saves refresh <0-4>` at the title replaces a co-op copy with a new copy of your save.
   Once the game saves inside the dungeon, that co-op save loads only while zMXIII_P is installed, and the camp is
   gone at the next game start (its row lives in memory only). Before you remove the pak, replace that copy with
   `coop saves refresh <0-4>`.
3. Type `coop mxiii`. It checks the pak and the travel's conditions, adds two rows to the game's tables in memory (the
   camp `DLC02_10_Camp_01` and the row that puts it in the dungeon's first zone, `Zone_DLC02_10`), then asks the game's
   own camp travel to go there, as `coop travel probe` does for a known camp.
4. If the log says `travel: SB refused DLC02_10_Camp_01`, the game listed its camps when the map started, before the
   rows went in. Load the save again (or travel to any camp), then type `coop mxiii` again: the rows stay until the
   game exits, so the second time it only travels.

- The pak check reads `zMXIII_P.utoc` once per command and looks for `WorldMap_DLC_01`, `Level_P` and `MXIII_P.umap`
  in it, with `zMXIII_P.pak` and `zMXIII_P.ucas` beside it. A pak under another name is not found. The check reads the
  folder as it is now: it cannot tell whether the game mounted the pak at start, and the game mounts paks only at
  start. Copy the files in with the game closed.
- The rows go in through the same native calls as `coop lion` and the shop's cut items. A fault in those calls during
  `coop mxiii` stops them all until the game restarts: `coop lion`, `coop gardener fight`, `coop tendril fight`, and
  the shop's stimpacks, ChainSpin and Shock Bolt that are not in yet then answer that the rows stopped on a fault.
- The camp never shows on the world map, and the mod adds nothing else: no zone warp, no quest step, no item.
- What you find there depends on the test pak. The dungeon's first zone spawns its enemies as you enter it (14 Antlions
  and a data drone in the game's spawn table).
- `coop off` ends the wait for the rows. A travel the game already took goes on.

| Line | What it answers |
| --- | --- |
| `[StellarCoop][MX] checks: solo on a co-op save, the native travel idle, <path> holds WorldMap_DLC_01/Level_P/MXIII_P.umap beside its .pak and .ucas` | The checks passed and the test pak holds the map |
| `[StellarCoop][MX] refused: no test pak: no <path> or <path>` | No test pak in either folder: nothing was asked |
| `[StellarCoop][MX] refused: no test pak: <path> does not hold <name>` or `no <path> beside <path>` | The `.utoc` names the map under another folder or not at all, or its `.pak` or `.ucas` is missing: nothing was asked |
| `[StellarCoop][MX] refused: <why>` | A condition of the travel failed (a session, another save, a travel under way or under 10 s ago, the native travel stopped by a fault): nothing was asked |
| `mxiii rows: 2/2 added through SB's AddRow 0x14417ba30, 0 refused` (`coop-link.log`) | The native part added the 2 rows |
| `mxiii rows refused <row>: <why>; <n>/2 added` (`coop-link.log`) | A row the native part would not add, and why: no travel |
| `[StellarCoop][MX] rows read back through FindRow: 2/2 authored rows, 4 fields as written (3 differ from the template row)` | Every field the native part wrote reads as written |
| `[StellarCoop][MX] travel to DLC02_10_Camp_01 asked: ...` | The camp travel went to the native part |
| `[StellarCoop][TR] travel accepted: DLC02_10_Camp_01` | The game took the travel: the fade and the load follow |
| `[StellarCoop][TR] travel: SB refused DLC02_10_Camp_01` | The game did not find the camp (see step 4) |

None of it has been tried in game yet. Check that the second try loads the map, that EVE stands on its floor at the
camp's spawn point, which enemies appear, and that the game keeps running and saves normally after you leave.

### Cut hairs and suits: `coop wear`

The game's files hold two hairs and four suits that no item gives. `coop wear` puts them on your EVE by setting the
meshes of her own hair and body components. It changes what is drawn and nothing else: your equipment, inventory, saves
and quests are never read or written, so the game's menus still show what you equipped and the next save keeps it. It
runs on any save and has not been tried in game yet. Its lines go to `UE4SS.log` as `[StellarCoop][WR]`.

| Name | Part | Mesh | What it is |
| --- | --- | --- | --- |
| `nyaaa` | Hair | `EVE_HR_14` | A bob cut with a lace headband and mechanical cat ears (Nyaaa, a hair whose name and description are in the game's text, with no item) |
| `rabbit` | Hair | `EVE_HR_15` | A bob cut with long mechanical rabbit ears (Mecha Rabbit, the same) |
| `gothic` | Suit | `CH_P_EVE_IberisCos` | Gothic Rose (`BS_1000`), the gothic dress of Iberis, Lily's late colleague |
| `rider` | Suit | `CH_P_EVE_03_Body` | Daily Rider (`BS_Leather_Jean2`), an earlier build of Daily Biker |
| `diving2` | Suit | `CH_P_EVE_01_TypeB` | Planet Diving Suit (5th) V2 (`BS_Blue_Suit_Var2`) |
| `golden` | Suit | `CH_P_EVE_InnerSuit1` | Golden Skin Suit (`BS_102_1`), with the placeholder materials of the asset |

The meshes are in `/Game/Art/Character/PC/`, the hairs under `00_HR/`. Each suit has an EquipmentTable row and no item.

- `coop wear` lists what is worn and the names.
- `coop wear <name>` puts one on. A hair and a suit can be worn together. A second hair or suit replaces the first. A
  hair also gets its own physics asset and its own animation Blueprint, which moves its ears and strands. On the part
  it changes, a slot where the game put a material of its own (your hair colour) shows the cut mesh's material.
- `coop wear off` gives the game's hair and suit back. `coop wear off hair` and `coop wear off suit` give one back.

A suit changes the body mesh alone. EVE's animations, face, ponytail and body collision stay as the game set them. The
ponytail keeps the colour and the cloth collision of what you equipped, so its strands may pass through a long dress.

The game can put its own meshes on again: after its wardrobe, a map load, a cutscene or photo mode. Once a second, while
the game is neither paused nor showing one of its screens, `coop wear` looks at the worn parts. A part that shows a mesh
of the game's again takes that look as the one to give back, then gets the cut one again, with a `re-applied` line in
the log. An outfit you pick in the wardrobe while a suit is worn therefore shows after `coop wear off suit`.

The look lasts until `coop wear off`, `coop off`, a Lua reload (Ctrl+R) or a game restart. While one is worn,
`coop-wear.txt` holds your EVE's own look, so the next Lua load gives it back if this one could not.

Your friend sees it. The capture reads the mesh of each part of your EVE every second. The ghost then loads the same
hair or suit from your friend's own game files, so nothing more is needed on that PC. The Gothic Rose dress has 385
bones, where the other suits here have 159 to 203. The capture and the ghost take up to 1024 bones a part, so the ghost
wears the dress on its own mesh, not the base suit. A cut mesh shows its own materials on both screens, with the `dyes`
look on or off.

### Cut scenes: `coop scene`

The game's files hold scenes that no cutscene trigger plays. `coop scene` plays two of them through the game's own
cutscene player, its theater. The camera follows the scene's cameras while your input and the HUD are locked, and other
characters are hidden. It has not been tried in game yet. Its lines go to `UE4SS.log` as `[StellarCoop][SC]`.

| Name | Scene | Where it plays |
| --- | --- | --- |
| `emil` | Emil's farewell (`/Game/DLC_1/Art/Cinema/MV_DLC_Ending_E03`), 48 s from an ending of the first DLC: EVE, the drone, a blockout Emil made of a vehicle mesh and grey shapes, 15 Stellar Tear cans and the scene's own cameras. It has no sound; Emil's five lines show as subtitles | The Wasteland, within 50 m of Emil's spot (11348, 22974, 418) |
| `orcal` | Orcal's monologue from the 2022 trailer (`/Game/Cinematics/Trailer_2022/Trailer_Resource_2022_Theater`), 39 s in his room, with his Korean voice and one Korean subtitle line that the game has no translation for | Xion, within 50 m of Orcal's room (34095, -1075, -34663) |

- `coop scene` lists the scenes and where each plays. Any save.
- `coop scene <name>` plays one. It runs only on a [co-op save](#co-op-saves), with EVE on the scene's map within 50 m
  of its spot (`coop where` prints where you stand) and not while a cutscene of the game plays. The scene moves EVE to
  its own spot.
- `coop scene stop` ends the scene. The game gives the camera, your input and the HUD back as after a skipped
  cutscene. Any save.

`coop off` ends a scene the same way, and so does the next Lua load (Ctrl+R) for a scene an earlier load left playing.

The game starts a cutscene from a row of its theater table. Two unused test rows, `LYC02GO_E_Theater_002` (play) and
`LYC02GO_E_Theater_003` (stop), point at a theater that is not in the game's files, and only a zone of a map that does
not ship uses them. `coop scene` checks both rows, sets their theater path in memory and asks the game to run the
first. Emil's farewell has no theater of its own, so it borrows the take of the game's Emil farewell
(`MV_Nier_Emil_GoodBye_WLA`): that take plays E03 while `coop scene emil` runs and its own scene again once E03 ends.
The rows keep the new path until the game exits. Nothing is written to a game file or a save. Neither scene holds a
quest event, and the trailer's own triggers, which add quests before they play, are not used.

The scene's subtitles are in Korean and Japanese, under keys that the game's translations do not have. `coop scene
emil` registers them for the game's language with the five lines Emil says in the shipped farewell
(`Seq_Subtitle_Nier_Emil_GoodBye_01_01` to `_05` of `StringTable_Seq`), which say the same thing. The Korean and the
Japanese rows show at the same times; if the game draws both, each line shows twice. When the registration fails (a
`STOP: text:` line), the next `coop scene emil` tries again.

Not known before a test in game:

- whether the game plays a theater asked from the mod's Lua and whether it plays E03 from the borrowed take (if not,
  the log says that the game's own farewell plays instead);
- in Xion, a second Orcal may show if the game's Orcal stands in his room: the scene moves him onto its own and makes
  him visible;
- whether the game's skip prompt shows (it should);
- whether a camera fade stays at the end. E03 opens on black and is clear from 3.7 s, then fades out from 43.0 s and is
  fully black from 47.8 s to its end at 48.3 s. A fade left after the scene is cleared, with a line in the log.

Do not save while a scene plays (the pause menu is locked anyway).

The 2022 Adam trailer (`Trailer_Adam_2022_Theater`) is left out. Its Adam and Lily exist only during one story step,
so they would be missing. Its first shot moves 374 pieces of the Xion hyperdrive room and keeps 336 material changes
until the area reloads, its master sequence moves four spawn points and three director events in it run code that has
not been read.

The log lines, in `UE4SS.log`:

| Line | What it answers |
| --- | --- |
| `rows: LYC02GO_E_Theater_002 and LYC02GO_E_Theater_003 -> MV_Nier_Emil_GoodBye_WLA; read back` | Both rows name the scene's theater |
| `take: MV_Nier_Emil_GoodBye_WLA take 1 MV_Nier_Emil_GoodBye_WLA -> MV_DLC_Ending_E03; read back` | `emil`: the farewell's take plays E03 |
| `text: game language fr; 10 keys registered, each reads its GoodBye_01 line` | `emil`: the subtitles in your language (a `STOP: text:` line says why not) |
| `play: CreateSBZoneEvent(6, LYC02GO_E_Theater_002) called; EVE 3.2 m from the stage` | The game was asked to play it |
| `playing: MV_DLC_Ending_E03, 1.0 s after the call` | The game plays it |
| `Emil's farewell ended after 48 s. (the farewell take back on its own sequence)` | Its end and what was put back |

### Cut scene lines: `coop lines`

The game's files hold the subtitles of scenes that were cut before they were voiced, and voice takes that nothing
plays. `coop lines <name>` shows one of these scenes in the chat's feed, line by line, at the times its level sequences
give, with the speaker's name before each line. In `enya` the voice takes play, with the subtitles the game has for
them. Nothing else plays: no camera, no character, and no sound in the other scenes. It runs on any save and writes
nothing. It has not been tried in game yet. Its lines go to `UE4SS.log` as `[StellarCoop][LN]`.

| Name | Scene | Lines | Length |
| --- | --- | --- | --- |
| `adam` | The first meeting with Adam in the Tetrapod (he replaces EVE's nerve module and makes the Hall of Records deal), then the drone on the arrival at Eidos 7 | 49 | 3 min 7 s |
| `warrior` | Quest_Sub_015, a side quest after Raven's attack on Xion: Mann in the empty Presence Chamber, then Orcal's recorded last message | 47 (2 more have no text in the game) | 3 min 47 s |
| `quinn` | Quinn, a Xion engineer who insists he is human, in three short barks | 10 | 27 s |
| `skyhall` | Sky Hall, an earlier route where Lily leads EVE and Adam through a temple toward the Great Desert | 37 | 1 min 29 s |
| `enya` | Quest_Sub_008, with Su and Enya in Xion: six takes of Enya's and one of Su's that the shipped scene leaves out, voiced, one after another | 7 (2 with a subtitle) | 29 s |

- `coop lines` lists the scenes, and the one running.
- `coop lines <name>` starts one. A second `coop lines <name>` replaces it.
- `coop lines stop` ends it. `coop off`, a Lua reload (Ctrl+R) and the co-op UI going off end it too.

The words come from your game when the scene starts: the mod holds only each line's start time and its key in the game's
`StringTable_Seq`, or for Sky Hall its subtitle section in the test sequence. The game has the `adam` and `warrior`
lines in English and Korean, and Quinn's in Japanese too. In its other languages the game itself gives the Korean text,
its source language, so the lines show in Korean and the command's answer says how many do. Getting English there would
mean switching the whole game's language or copying the lines into the mod, and `coop lines` does neither. The Sky Hall
lines are Korean placeholder text in every language, most with the speaker's name inside.

The `enya` takes have no level sequence, so each one starts 1 s after the one before ends. They are the game's
`/Game/Sound/Dialogue/Quest/Enya/Seq_Quest_Sub_008_02_05_VO` to `_16_VO` (05, 06, 09, 10, 15 and 16) and Su's
`Seq_Quest_Sub_008_02_11_VO`, loaded when the scene starts. The game holds them in 10 voice languages, and the log
line below tells which one plays. Only `02_10` and `02_11` have a subtitle in the game's table; the other five play
with nothing in the feed. Each take plays as a 2D sound, not placed in the world. `coop lines stop`, a new scene and
`coop off` cut the take playing; with the co-op UI off, the scene ends at its next take. The log gives each take's
length and sound class when the scene starts
(`take Seq_Quest_Sub_008_02_05_VO: 3.42 s, sound class Dialog_NPC`: `Dialog_NPC` is the Korean take, a class ending in
`_En` the English one), and `enya line <n>: take not played (<why>)` for one that could not play. A take the engine
unloaded after the start is loaded again at its turn, with a short stutter, and logged as
`take <name> loaded again: freed before its turn`.

The lines need the chat's feed, which draws every script the game has (the notice line above EVE draws Latin letters
only): without the Steam link or with the co-op UI off, the command answers `STOP`. While the chat box is closed, the
feed shows each line for 8 s, 6 rows at most. A scene goes on while the game is paused.

### Emotes: `coop emote`

`coop emote <name>` plays one of EVE's animation clips on her. It runs on any save and writes nothing. It has not been
tried in game yet.

| Category | Names |
| --- | --- |
| Greetings | `salute`, `kungfu`, `toast`, `wave`, `wave2` |
| Expression | `clap`, `heart`, `thumbsup`, `victory`, `kiss` |
| Orders | `bringiton`, `giveme`, `hush`, `reach` |
| Emotion | `omg`, `what`, `worry`, `wish`, `wedidit` |
| Pose | `charm`, `confident`, `cutie`, `sweetie`, `squat`, `stretch`, `warmup`, `walk`, `shutter1`, `shutter2`, `shutter3` |
| Dance | `flow`, `nataraja`, `somersault` |
| Cut | `chariotstruggle`, `chariotcounter`, `chariotfail`, `chariottakedown`, `kalitakedown`, `kaligrab` |

- `coop emote` and `coop emote list` print the names by category.
- `coop emote <name>` starts one, and a second name replaces it. It does not start while EVE is in the air or in the
  middle of an attack or a dodge.
- Moving, a jump, a dodge or an attack ends it with a 0.25 s blend. So do `coop emote off`, `coop off`, a map change,
  photo mode and the game ending the clip itself. A Lua reload (Ctrl+R) stops a clip the earlier load left playing.

The first six categories are those of the game's cut Social Action menu, whose own gestures never shipped. Their 31
poses come from photo mode. Each one is a still of 0.2 s at most, played in a loop, so EVE takes the pose and keeps it
until she moves. The other eight clips play once and end by themselves:

- `wave` and `wave2` are the selfie mode's two waves (`Hello_Selfie_L` and `Hello_Selfie_R`, 3 s each). In selfie
  mode they sit in a blend space that follows the camera's direction; here each one plays whole.
- The Cut category holds clips of EVE's made for two enemies that have no character in the game files: no mesh, no
  `CharacterTable` row and no name in the game's text. The Chariot was removed (a test spawn row and a despawn effect
  still name it): its struggle (`chariotstruggle`, 14.8 s) and its two endings as the files name them,
  `ConfrontAttack` (`chariotcounter`, 10.0 s) and `ConfrontFail` (`chariotfail`, 1.5 s), and her takedown on it
  (`chariottakedown`, 4.9 s). Kali may be a cut enemy or an early name of one that shipped: her takedown on Kali
  (`kalitakedown`, 5.6 s) and Kali's grab (`kaligrab`, 5.8 s). In all six, EVE acts alone.

The native part plays the clip through the game's own custom animation call, the one the game uses for EVE's flight
start, so it goes through the custom animation nodes of her animation blueprint. Without the native part, on another
game build or after a fault in that call, the clip goes in as an animation montage instead, which most likely shows
nothing: her blueprint has no montage slot in the game files read for this version. A linked friend sees what your EVE
shows, through the pose stream the ghost already copies.

Its lines go to `UE4SS.log` with the `[StellarCoop][EM]` tag. With the native part:
`emote clap: Clap asked of the native part (anim 482913, loop)` when one starts (`once` for the eight clips above),
`emote clap: Clap plays (anim 482913)` once the game took it, and `emote clap ended (movement input) after 4.2 s` when
it ends. Instead of `movement input` the end line can say `in the air`, `a skill runs`, `the clip ended`,
`her animation blueprint showed nothing`, `the game refused it: <why>`, `no answer from the native part` (none in
5 s), `the native clips stopped` (a fault), `her EVE changed` (a map change), `another emote`, `coop emote off`,
`coop off` or `error`. When the clip did not show, a line also goes on screen and to the log as
`[StellarCoop] STOP: ...`: `coop emote: EVE did not show Clap`, `coop emote: the game refused Clap (<why>)` or
`coop emote stopped: <why>`.

The native part's lines go to `coop-link.log`: `anim 482913 asked: <path> in a loop` (or `once`), then
`anim 482913 playing: SB took the clip in EVE's custom animation slot 0 (ret 0)`, and at the end
`anim 482913 ended after 4.9 s, weight up to 1.00` or `anim 482913 stopped after 4.2 s, weight up to 1.00`, with
`(coop off)` or `(a new Lua load)` after the time when one of them stopped it. The weight says how much of the clip
the blueprint blended in: 1.00 is all of it. `anim 482913 refused: no EVE of ours in the world`,
`refused: EVE has no custom animation slot` and `refused: the game played nothing (ret -1: the clip did not load, or a
clip of a higher priority holds the slot)` say why nothing played; `refused: coop off` and `refused: a new Lua load`
name a play asked just before one of them. A clip the blueprint takes no weight of for 1 s
ends with `: the slot took no weight, so EVE's animation blueprint did not show the clip`. Time while the game is
paused (`coop freeze`, or a host's photo mode holding the guest) does not count toward that second, since EVE's
animation does not move then; the `after ... s` figure is still the clock's. A fault in the game's call
logs `anim fault ...`, says on screen that the native clips stopped until the game restarts, and sends later emotes to
the montage.

Without the native part the start line is
`emote clap: Clap in DefaultSlot, montage AnimMontage /Engine/Transient.AnimMontage_0, playing yes`, and
`the montage no longer plays` replaces `the clip ended`. `emote clap: no montage made for Clap` means the game refused
the montage. After a Lua reload, `emote restore: an earlier load's montage stopped` says the earlier montage was
stopped, and `emote restore failed: <why>` says it could not be. In both cases, after `error` comes
`coop emote stopped: <why>`, repeated as `[StellarCoop] STOP: coop emote stopped: <why>`, and a stop that fails adds
`: not stopped (<why>)` to the end line.

### Debug flight and slow motion: `coop fly` and `coop slowmo`

The game's code holds two developer tools that it ships switched off: a flight move and a slow-motion key. Each one
waits on a setting of the game's (`UseFlyingActionKey`, `UseTimeControlKey`) that only a cheat command sets, and that
command does nothing in the released game. `coop fly on` and `coop slowmo on` have the native part set the setting in
the game's memory, and `off` puts the game's value back. These test commands are left out of the usage line, need the
native part and run on a [co-op save](#co-op-saves) only. The flight was tried in game once, with the game's Z key.
The first space bar start was tried on 2026-10-26 and started no flight, since it read a flag the game never sets; the
current one has not been tried in game.

- `coop fly on`: press the space bar a third time while EVE is in the air, and she flies. The jump and the double jump
  are the first two presses, as in the game, and holding the second one still glides with `coop glide on`. After a
  fall from a ledge, it takes three presses in the air. Z and S no longer start a flight; R2 held on a pad still does,
  as in the game. The game's flight carries her along the camera's heading at 10 m/s: turn the camera to steer. Z held
  climbs, S held descends, and with neither she flies level until you press the space bar again or the flight ends on
  its own (landing, or its time pool). The third press does not need to stay held: if the game is not ready to start
  the flight yet (an action still playing, or less than 0.5 s since the last flight), it starts as soon as it is,
  unless she lands first. The press that starts the flight does not drop her, even if you keep it held. After a drop
  the count starts over, and with `coop glide on` the space bar held after the drop glides. Flight time comes from a
  pool of 90 s that drains while she flies and refills at 1 s per second, the game's own values. During a flight the
  face buttons dodge up, down, left and right, and so do Shift with Z, S, Q or D on the keyboard (up, down, left,
  right). `coop fly on` writes R2 over Z (and over any third slot) in the game's flight key list and adds the four
  Shift keys to the input settings. The game itself ends a flight once no flight key is held. The native part hooks
  the player controller's key pass and, right after it, counts the space bar's presses since EVE left the ground. From
  the third one it sets the flight key each frame until the game starts the flight or she lands. While EVE flies with
  no flight key held, it sets the key again each frame, until the next press. The log's `[FL]` lines say once a flight
  whether the level flight held. The game sets the flight's velocity whole each frame, with no easing: the mod eases
  the climb and the descent in and out over 0.3 s, and starts a flight at 40 % of its speed, full after 0.6 s. Turns
  follow the camera at once, as in the game.
- `coop slowmo on`: hold R1 on a controller and time runs at 0.2 of its speed until you release it. The game binds no
  keyboard key to it. It waits while a friend is linked, since the slow time would be your game's alone.
- `coop fly off`, `coop slowmo off`, `coop off` and a Lua reload (Ctrl+R) put the game's values back. On a save that is
  not a co-op one, both wait until you are back on one. Nothing of it is saved: the game builds these settings again
  at each start.

The keys keep their other uses. R2 is also Interact and the fishing reel, and R1 opens the Burst skills. So with
`coop fly on`, holding R2 in the air flies, and with `coop slowmo on` holding R1 for a Burst skill slows time. Flight
can carry EVE past places the game expects her to reach on foot, and the next save keeps where she is: hence the co-op
saves only.

The native part's lines go to `coop-link.log`: `coop fly on: UseFlyingActionKey set at the game thread's next pass`,
then `gate fly: on, ours, 1 writes` once the setting is set. Once a second, when one of its counts changed, the hook
logs a line such as `fly hold: 5400 steps, 7 presses, 1 armed, 12 armed writes, 1 takeoffs`: how many frames it ran,
the space bar presses it saw, the third presses in the air, the frames it set the flight key before a takeoff and the
flights it saw start. When the game's memory does not hold the setting the way the pinned build does, the native part
writes nothing, logs why and says `coop fly refused: ...` on screen. The level flight's hook goes in at the first
`coop fly on` of a game run (`level flight on: 0x145cc74a8 and 0x145cd37a8 swapped from the game's input pass to our
hook`) and stays until `coop off` (`level flight off (coop off): 2 of 2 slots hold the game's input pass again`); in
between it does nothing while `coop fly` is off. If another mod already changed
those slots, it logs `level flight refused: ...` and leaves them alone: the space bar then starts no flight, and R2
flies only while held. A fault in the hook takes the hook out for the rest of the run and says so on screen.

### Cut glide: `coop glide`

EVE's movement code still holds the end of a glide that was cut: a flag that makes her fall at a tenth of the normal
gravity while it is set. Nothing in the game sets the flag any more. Its config keeps a Jump hold time for it (0.2 s)
that no code reads, so no setting or cheat turns it on. `coop glide on` has the mod set the flag itself, with that hold
time. This test command is left out of the usage line, runs on a [co-op save](#co-op-saves) only and has not been tried
in game yet.

- With `coop glide on`, hold Jump (Space, or A/Cross on a controller) in the air. Once Jump has been held for 0.2 s and
  EVE is past the top of her jump, she glides until you release Jump or she lands. To glide after a double jump, hold
  the second press.
- A glide does not stop a fall. EVE keeps the downward speed she had when it started and gains speed ten times more
  slowly, so a glide started right after the top of a jump is the slowest. Her air control stays the game's.
- Only the game's default Jump keys count. A Jump key changed in the game's settings is not followed.
- She does not glide during the developer flight (`coop fly`), whose own gravity the glide would replace.
- How it looks is unknown. The game has three glide animations (`Proto_Glide`, `Proto_Glide_1`, `Proto_Glide_Start`),
  but whether its animation graph still plays them is not known, so EVE may glide in her fall pose.
- `coop glide off`, `coop off` and a Lua reload (Ctrl+R) clear the flag. On a save that is not a co-op one, she does
  not glide until you are back on one. Nothing of it is saved.

As with the flight, a glide can carry EVE to places the game expects her to reach another way, and the next save keeps
where she is. That is why it runs on co-op saves only.

Its lines go to `UE4SS.log` with the `[StellarCoop][GL]` tag: `glide on EVE (velocity Z -120 cm/s)` when a glide
starts and `glide ended (landed) after 2.4 s` when it ends, with `Jump released` or `flight or rising` instead of
`landed` when that is what ended it.

### Cut Load Shortcut saves: `coop shortcut`

The game still holds a cut menu, Load Shortcut, that started a developer save at a set point of the story. Its button
never shows on the title screen, and the menu loads nothing: its load call was removed. The saves it lists are still in
the game's files, 15 of them for four maps (B07 4, F02 3, G03 4, Matrix_XI 4).

`coop shortcut` lists them. The native part reads each file from the game's paks through the game's own file manager,
one per frame (16 frames in all), and writes nothing. The command runs on any save, needs the native part, is left out
of the usage line and has not been tried in game.

Each file gets a line in `coop-link.log`:

```
shortcut F02 1: start point 1, map F02 (DrownedEidosDistrict), camp DED10_EnvS_158, saved 2022-04-15, ++UE4+Release-4.26, 1185648 bytes
shortcut F02 4: none
shortcut G03 2: the same bytes as F02 1
```

The map is where the save starts, with its world's name in the game's tables, and the camp is the one it starts at.
F02's three files are the three numbered start points of the game's cheat list (Eidos 7, Matrix 11, Spire 4). A
summary follows, which also reaches `UE4SS.log` as a `link: last=` line: `shortcut saves: 15 of 16 found: B07 1
SE_01_EnvS_049, ..., G03 2 = F02 1, ...; each one's line is in coop-link.log; loading one is held back`. A second
`coop shortcut` before the list ends still answers `OK: asked the native part: shortcut list: ...` on the console; the
refusal, `shortcut list refused: a list is under way`, shows in `coop-link.log` and in `UE4SS.log` as a `link: last=`
line.

Loading one is held back. These are saves of development builds from 2021 and 2022. Two of them (F02 2 and 3, and
their copies G03 3 and 4) hold six boss achievements as already done, and loading one could give those Steam
achievements to an account that never fought the bosses. They also hold items and quests the released game no longer
has, and lack fields its own saves have. [How it works](how-it-works.md#why-no-load) has the details.

### Developer menu: `coop devmenu` and `coop devinfo`

The game's files still hold the cheat menu the developers used (`WB_DebugCommand_Master`), its data table of 7,139
rows over 18 tabs, and a few debug panels. The menu cannot open in the released game: the code that fills it is not in
the build, and every row's command goes to the game's cheat manager, where 702 of the 703 commands only read their
arguments and return. The game's own cheat request still runs six words, and 87 rows use three of them
(`SBApplyEffectMe`, `SBPlayerSP`, `SBPlayerRevival`). Both commands are test commands, left out of the usage line, and
neither has been tried in game yet.

`coop devmenu` gives back the rows among those 87 that grant nothing by themselves and whose lasting effects a row of
its own can end. `coop devmenu` or `coop devmenu list` lists them,
and `coop devmenu <row>` runs one, on a [co-op save](#co-op-saves) only. The mod reads each effect's ID from the
game's EffectTable by name and asks the game to apply it on EVE, through the same request as
[`coop chainspin`](#cut-tachy-skill-coop-chainspin). Its lines go to `UE4SS.log` as `[StellarCoop][DM]`, one per
effect: `devmenu attack30: SBApplyEffectMe Test_ShieldDamageUpMe30 (9000178) on EVE (guid 228)`.

| Row | What it does |
| --- | --- |
| `nodamage` | EVE takes no damage |
| `stealth` | EVE is hidden from enemies (the game's stealth state) |
| `speed150`, `speed200` | EVE moves 1.5 or 2 times as fast |
| `attack5`, `attack30` | EVE deals 5 or 30 times the damage, to health and shield (each run adds to the last) |
| `gauges` | The Beta and Burst gauges refill on their own |
| `tachy` | The Tachy gauge refills on its own |
| `tachyfull` | The Tachy gauge fills, once |
| `heal` | EVE's health fills, once |
| `hp1` | EVE's health drops to 1, once |
| `nolockswitch`, `lockswitch` | The lock-on stays off when its target dies, or moves to the next target again (the game's way) |
| `enemynodamage` | Enemies near EVE take no damage |
| `enemynoai` | Enemies near EVE stop acting |
| `enemyimmortal` | Enemies near EVE cannot die |
| `enemyshield1`, `enemybalance1` | Enemies near EVE drop to 1 shield or 1 balance, once |
| `enemyclear` | The lasting effects above come off the enemies near EVE, and most likely off EVE too |
| `clear` | The lasting effects above come off EVE and the enemies near her |

- "Near EVE" is the range the game's test effects use. Run the row again after you move to reach other enemies.
- Only your game runs a row. With [shared enemies](#shared-enemies-experimental) on, the health that `attack5` and
  `attack30` take off a shared enemy and the balance that `enemybalance1` takes come off its shared HP bar and balance
  gauge, so they count in your friend's game too, and a shared enemy that dies that way gives your friend the kill if
  they took part in its fight (`kill_credit`). The other enemy rows change your copies only, so they may act
  differently from your friend's.
- Effects that last stay until `clear` (or `enemyclear`; `nolockswitch` until `lockswitch`) or the game's exit. A save
  load should end them too, but that has not been checked. `coop off` runs `clear` and `lockswitch` once more when a
  row ran, even before a Lua reload (Ctrl+R; `coop-devmenu.txt` keeps that). That `clear` reaches only the enemies near
  EVE at that moment, and both rows are skipped while a respawn or a warp is under way or no EVE is in the world: the
  log then has `coop off: devmenu clear not asked: <why>`. After `coop off` no `coop devmenu` row runs, so run `clear`
  near the enemies you changed before it. Nothing of it is saved.
- Running a lasting row twice does not turn it off. `attack5` and `attack30` add up at each run: `attack30` twice
  gives about 59 times the damage, and `attack5` then `attack30` about 34 times. The speed rows do not add up.
- Left out: the rows that kill enemies or cut their health (EVE would get the kill, its rewards and its trophies
  without the fight), the ranged mode unlock, the consumable stacks, the fishing cheat, the skill points, EVE's death
  and revival, the test stances and skills, the effects on every actor, and the effects no row can remove: the full
  immunity, the two 80 % damage cuts, the scanner without cooldown and the menu's endless stun of the enemies
  (`Test_EnemyEffectGroggy`, which neither dispel ends).
- No row grants an item, a skill point, a quest step or a trophy by itself. Kills made with the help of the attack,
  gauge or enemy rows are still EVE's kills: they count toward the kill and skill trophies in the co-op save, as any
  other kill does.

Which tabs of the menu still do something:

| Tab | Rows | Rows the cheat request still runs | In `coop devmenu` |
| --- | --- | --- | --- |
| Common | 225 | 53 | 25 |
| Battle | 207 | 12 | 7 |
| CombatTestMapMk2 | 23 | 4 | 2 |
| System | 4,679 | 17 | 1 |
| Level | 1,514 | 1 | 0 |
| F01, F02, B07, C05, G03, E03_WasteLand_P, E04, E05_GreatDesert_P, AltesLab_P, AbyssLab_P, Matrix_XI, LV_RavenBoss_Test, UI_LIT_TEST | 491 | 0 | 0 |

The map tabs hold warps, quest steps, item grants and achievement unlocks, all of them commands that do nothing in
this build. 37 rows are engine console commands (FSR settings, `stat`, `show`), which the game's console runs without
the menu.

`coop devinfo quest` opens the game's quest debugger: a list of every quest the game holds, with its task groups and
tasks, which the game writes again each frame while it is open. `coop devinfo player` opens the player info panel,
whose one line reads `PlayerTagName:` and a text from the game's client whose contents are not known yet. Opening one
closes the other, and `coop devinfo off` closes both. The native part opens and closes them through the game's own UI
manager, as the game opens its menus. Both panels only read, so they run on any save. They open only when the game is
in play, which is part of the check the game makes before it opens one of its own panels (the mod does not read the
rest of that check): on the title screen or during a load the line says `not in game` or `not playing`. `coop off`
closes them. The boss challenge debug panel cannot open: like the menu's, its code is not
in the build. The native part's lines go to `coop-link.log`: `coop devinfo quest asked: at the game thread's next
frame`, then `devinfo quest: 0 closed, 1 opened`, or `devinfo quest refused: not playing, 0 closed`.

### Cut mailbox: `coop gift`

The game's files hold a mailbox that was cut: its menu (`WB_MailBox_Set`, with a detail panel and list rows), a toast
for a new gift (`WB_MailBox_Toast_GetGift`), their textures and the sound `UI_MailBox_GetGift`. The two gift rows left
in its table turn a mailbox on only for an object of a test map that is not in the game, and their titles were never
written. The menu's code is still in the game, but it only lists those rows, and taking one of its gifts writes that
gift into the save. `coop gift` uses the mailbox for gifts between two players instead: your linked friend sends you
consumables from her inventory, they wait in your mailbox, and you take them when you want. Both of you must play a
[co-op save](#co-op-saves). None of it has been tried in game yet.

| Command | What it does |
| --- | --- |
| `coop gift` | Lists what waits in your mailbox, what you sent that waits for an answer, and the items you can send |
| `coop gift send <item> [count]` | Sends 1 to 10 of one item to your linked friend, 1 when the count is left out |
| `coop gift take [n]` | Puts every gift that waits into your inventory, or only gift n of the list |

The item is its number or its name, in any case:

| Number | Name | In the game |
| --- | --- | --- |
| 1 | `HP_Potion` | Highly Concentrated Potion |
| 2 | `HP_Potion_Small` | Lingering Potion |
| 3 | `HealGrenade` | Biotic Field Generator |
| 4 | `PulseGrenade` | Pulse Grenade |
| 5 | `ConcussionGrenade` | Shock Grenade |
| 6 | `TrapGrenade` | Smart Mine |
| 7 | `FlashGrenade` | Sonic Grenade |

Only these consumables can be sent. Key, story and quest items, equipment, the Tumbler (whose charges the game keeps as
a stat), drone ammo and the cut stimpacks are left out, and none of the seven counts toward a trophy.

- A send checks how many of the item you carry and refuses when you have fewer than the count. The game then takes the
  items out of your inventory with its own remove request, and the gift goes only once a second read shows they left.
  That wait lasts 10 s of play at most: time with the game paused or in photo mode (yours, or your friend's when it
  pauses your game) does not count, since the game runs the remove only once it plays again.
  `OK: reading how many PulseGrenade you carry; the gift of 2 follows` answers the command, then a notice says
  `Gift sent: 2 PulseGrenade. It waits for your friend's answer.` or why it was not sent.
- Your friend's game keeps the gift in her mailbox and answers, and you get `Kaanta got your 2 PulseGrenade.` She gets
  `<your name> sent you 2 PulseGrenade: coop gift take puts them in your inventory.` and the cut toast for 4 s. A Lua
  reload (Ctrl+R) in those 4 s takes the toast off at once.
- Her game refuses a gift when she is not on a co-op save, when 20 gifts already wait in her mailbox, or when it cannot
  write its mailbox file. The items then come back to you: `Gift refused (full): the 2 PulseGrenade come back.`
- The items also come back when she leaves the session before answering, when no answer came in 60 s, or when the
  gift could not be sent at all. They come back through the same request the
  [Night Operation shop](night-operation.md#the-reward-shop) adds items with, as soon as EVE is in the world and the
  game is not paused, and only on the co-op save they left.
  `Gift returned: 2 PulseGrenade are back in your inventory.` says it.
- While she is linked and has not answered, the gift is sent again every 10 s under the same number. Her game keeps
  that number with the gift, and keeps the last 64 it took or refused, so a gift sent twice is kept once.
- `coop gift take` puts the gifts in your inventory through the same request as the shop, `OK: took 3 HP_Potion from
  Kaanta`. The game must not be paused. A gift is crossed off your mailbox before the game adds it, and put back if
  the game refuses the call.
- `coop loopback` with no friend linked sends a gift to yourself, for a test on one PC: the items leave, arrive in your
  own mailbox, and `coop gift take` puts them back.

These cases can still lose or double a gift:

- Your friend's answer is lost as she leaves the session, or her link stays lost for more than 60 s while the gift
  line is on its way. The items come back to you, and her game keeps the gift if the line reaches it. The log shows
  `gift <id> comes back: ...`, and an answer that arrives after it shows `answer a <id> for no gift waiting`.
- The game stops (a crash, `coop off`, a Lua reload) after the remove and before the gift's entry in your file, which
  can take up to the 10 s of play above plus 5 s for a read. The items are gone and nothing is sent: the log has a
  `remove asked` line with no `sent` line after it.
- The count does not fall by the gift's in those 10 s, because the game ran the remove later still or because an item
  you picked up meanwhile hid the drop. Nothing is sent, and the notice says the items may be gone:
  `Gift not sent: the count did not fall by 2 in 10 s of play (5 before, 4 now); the items may be gone`. Check your
  inventory.
- You use the same item between the remove request and the game's turn that runs it. The use can look like the drop,
  so the gift goes, and the remove then takes only what is left.

The mailbox is a file per Steam ID and co-op slot in the mod folder, `coop-gift-<steamid>-<index>.txt`, like the shop's
points: restoring a save backup does not change it. Its lines go to `UE4SS.log` with the `[StellarCoop][GF]` tag:
`remove asked: PulseGrenade x2 of 5 (guid 228)`, `sent <id>: PulseGrenade x2 to <SteamID> (had 5)`,
`gift <id> kept by Kaanta: PulseGrenade x2`, `gift <id> comes back: your friend left`,
`took <id>: HP_Potion x3 from <SteamID> (guid 228)`.
`coop-link.log` has each gift line both ways (`gift line sent: s <id> PulseGrenade 2`,
`gift line from Kaanta: a <id>`).

Check in game that a send takes the items out of your inventory and that a take adds them, that the counts in
`[GF]` lines match the inventory screen, that the toast shows its icon and whether it plays a sound, and that a gift
refused or left unanswered comes back once.

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
dies. With `fought`, the distance does not count, and with either value it does not count while your EVE is down.
Whether it targeted you or your hit landed comes from the game's record of the last player an enemy fought, the record
the game itself uses to credit a kill. An enemy that your own hit kills always gives you the kill. When the other player
kills a shared enemy you took no part in, your copy does not die: it stops being shared and stays alive in your game,
back at full HP, so its kill rewards, drops, quest kills and achievements never reach your save, and one hit of yours
later does not finish what the other player's hits did. A boss copy goes back to full HP the same way. Whether you can
then beat that boss alone before the area reloads has not been tested in game. The guest's `coop-link.log` then says
`fight dead-unshared <key> hguid=<n> not taken part`, the host's says `fight kill-unshared <key> hguid=<n> not taken
part`, and the host's game does not share that enemy again in this session. As the guest, while [same
spawns](#same-spawns-experimental) run (within 100 m of each other in one zone), the host's next drop line removes the
copy of a common enemy from your game a few seconds later, without a kill, unless you are fighting it. Damage dealt
before an enemy became shared does not count as yours, since the other player may have dealt it. When a knockdown the
other player started, mirrored on your copy, makes the game record your EVE as that enemy's last player, the log says
`fight last player <key> set by a mirrored crowd control` and that record no longer counts for this enemy: your hit or
the 30 m still do. `kill_credit=all` from 0.4.0-beta.1, which gave you every shared kill wherever you stood, is gone
(see [coop-settings.txt](#coop-settingstxt)).

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

When your friend's game loads other `.pak` mods than yours, a notice says so once a session. The mod compares the
`.pak`, `.ucas` and `.utoc` files beside the base game's in `SB/Content/Paks` and its folders (`~mods`, `LogicMods`),
by name and size; `coop-link.log` lists yours at its start. With the names of your friend's mods (their `mod_names=on`,
the default), it names those they use and you lack, and those you both have in another version, up to two file names
each, then `(+n)` for the others:

- `Kaanta uses mods you don't have: lily_hair_p, hd-atool_p (+1). Parts of their outfit from them look different here.`
- `Kaanta uses other versions of mods you have: menu_p. Parts of their outfit from them may look different here.`

Without names (their `mod_names=off`), or when only you have mods they lack, it gives the counts instead:
`Kaanta loads other .pak mods than you (1 there, 2 here). Enemies that differ stay unshared.` It is a warning only.
`coop status` lists the three groups in full (`mods_missing=`, `mods_other=`, `mods_extra=`). With `mod_names=off`
in `coop-settings.txt`, your game sends only the count and the hash of your mods, never their names, and your capture
leaves out every path from a mod's own folder (see [Mods and CNS outfits](#mods-and-cns-outfits)).

The guest also sees two notices while enemies are shared. `Shared enemies: some enemies have another max HP in <name>'s
game (another difficulty or New Game+). They stay unshared.` shows once, until shared enemies stop or the friend
leaves, when an enemy of the host's cannot be paired because its maximum HP differs (by more than 0.5, before any
scaling). `Shared enemies: <name> is down. Once they respawn, the enemies you share go back to full health.` shows each
time the host goes down while enemies are linked: the host's respawn resets the enemies in the host's game, and your
copies follow them back to full health. A respawn on another map leaves your copies unshared, with the HP they had.

- `coop fight on` asks for it by hand (it needs `shared_enemies=on`) and `coop fight off` stops it until the mod reloads
  or the row is turned off and on again. It waits for a linked friend, a loaded save and a co-op save, and pauses while
  either player is in photo mode (selfies and the pause menu do not pause it). Loading your own save pauses it until you
  load a co-op save again. Setting `shared_enemies=off` in the file and pressing Ctrl+R also stops it (the solo test
  tools below keep running).
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
a few seconds later. The same happens after each reset of her zone, unless she turns the
[spawn filter](#spawn-filter-experimental) on.

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

### Spawn filter (experimental)

`spawn_filter=on` in the guest's own coop-settings.txt keeps away, in her game, enemies that the host's game no longer
has. It is off by default, has no row in the co-op menu, and has not been tested in game. On, the mod changes one
pointer in the game's memory on her PC ([how-it-works.md](how-it-works.md#the-spawn-filter)).

With it off, [same spawns](#same-spawns-experimental) work as above: when her zone resets (her death, a camp rest),
her game spawns its own enemies again, the ones the host's game lacks among them, and the host's next drop lines remove
them a few seconds later. With it on, her game does not spawn those enemies at all. The filter knows two kinds: an
enemy her game removed on the host's drop line, and a shared enemy whose death came from the host's game and that died
in hers too (she took part in its fight). A spawn line from the host's game for one of these takes it off the list
before her game creates it, so an enemy that the host's game holds again comes back. The list empties at the host's
next epoch (its zone changes or resets), at a world change in either game (a load, or a check that finds every enemy
new: `fight world <why>` in `coop-link.log`), and when the session ends. Whether her deaths and camp rests count as
world changes in her game has not been tested yet; one that does is not covered by the filter.

- The first entry into a zone still shows the old spawn and its removal: her game learns what the host's lacks only
  from those drop lines and deaths. The filter covers her later resets there, until the host's next epoch, except a
  reset that is also a world change in her game (see above). It holds 240 enemies at most; one more spawns and is
  removed, as with the filter off.
- The filter only refuses a spawn. It never kills, so a refused enemy gives no kill, reward, drop or quest progress,
  and no death of it is recorded. Quest and zone event enemies are other rows and never reach the list.
- It refuses spawns on the guest's side only, on game build 24463856, and its list fills only while the host's
  `same_spawns=on` runs. The setting is read when the mod loads and counts from the next start of shared enemies.
- The pointer is changed once a run, when shared enemies first start with the filter on the guest's side (or at
  `coop fight spawn probe`), and stays changed until `coop off` or the game exits. Between sessions every spawn passes.
  `coop off` puts the game's pointer back at once. To turn the filter off, close the game and set `spawn_filter=off`.

The guest's `coop-link.log` says:

- `spawn filter on: 0x145c10020 swapped from the game's Execute to our filter`: the filter is in place.
- `spawn filter refused <spawnId>:<index>`: her game asked to spawn that enemy, and the filter refused it. Her game asks
  again after a while; each enemy is named once a session, and later refusals only count. `spawn filter: <n> more
  refused, not listed` counts the ones the log did not name.
- `spawn filter refused: 0x145c10020 holds <address>, not the game's Execute (another mod's hook?); ...` or `spawn
  filter refused: the page of 0x145c10020 would not become writable (error <n>); ...`: the filter did not start, and
  every spawn goes on as with it off. Nothing was written.
- `spawn filter fault <code> in <where> reading <address>: off for this run`, then `spawn filter off (a fault): ...`:
  a fault in the filter's lookup turned it off until the game restarts.
- `spawn filter off (coop off): 0x145c10020 holds the game's Execute again`. If another value is there by then, the
  line names it and the mod leaves it.

While the filter is in place, the `fight stats:` lines in `coop-fight.log` add `filter <n> seen, <n> refused`: the
spawn requests it looked at and those it refused.

`coop fight spawn probe` with `spawn_filter=on` puts the filter in place with an empty list, so every spawn passes and
`seen` counts them. It checks the pointer change on one PC.

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
run or a challenge (it ends as aborted, and so does the partner's co-op run; your shop points stay as they are), the
Night Operation poller, the Night Operation shop screen (closed, its seeds back in your wallet), Roxanne's Night
Operation choices (her own two back, and a run booked at her dropped), a recruiter (despawned if one was requested, in
Xion), the shared quests, the photo pause
(released; the native tick keeps running for this alone), a Doro race (left as a DNF, or cancelled before GO, with EVE's
movement values put back), the drive probe, a race track being recorded (dropped, nothing written), the Doro look (EVE
drawn again), the cut model display and its free camera (`coop leviathan` and the other viewer commands; the view goes
back as it was), what `coop lion` is doing (a wait for its rows, its search, its entrance copy, its log lines; a living
Lion stays), the same for `coop gardener fight` and `coop tendril fight` (a living Gardener or Tendril stays), the
`coop wear` look (your EVE's own hair and suit come back), a `coop lines` scene, the game's
developer flight and slow motion (`coop fly` and `coop slowmo`: the game's values come back), the cut glide
(`coop glide`: EVE's glide flag is cleared), a `coop emote` clip (it blends out), the game's developer panels
(`coop devinfo`: closed), a `coop shortcut` list under way and the gift toast (taken off the screen). When a
`coop devmenu` row ran, `coop off` runs its `clear` and `lockswitch` rows once more, but that `clear` reaches only the
enemies near EVE at that moment, and both are skipped while a respawn or a warp is under way (see
[Developer menu](#developer-menu-coop-devmenu-and-coop-devinfo)). A `coop gift send` caught after the items left your
inventory and before the gift reached your mailbox file stops there, and those items are lost. Gift lines from your
friend that arrive after `coop off` are dropped without an answer. Afterwards only `coop status` and `coop report`
answer. Every other command answers `STOP: coop off is active until the game restarts`,
and so do the menu, host and leave keys. The race key does nothing.

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
# the co-op menu, whose first row hosts; host_key hosts at once, or none. follow_key travels to the host (follow_host
# below), or none. race_key drops a checkpoint while you record a race track (coop race record).
menu_key=F5
host_key=none
status_key=F6
leave_key=F8
follow_key=F7
race_key=F9
# The keys you hold to drift in a Doro race: Unreal key names separated by spaces (at most 4), or none. Steering hard
# at speed drifts too, with no key. The defaults are R2 on a pad (it still picks up items in reach, as outside a race)
# and B on the keyboard, which Stellar Blade leaves free.
drift_keys=Gamepad_RightTrigger B
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
# Spawn filter, experimental, yours, used when you are the guest and the host has same_spawns=on: on or off, off
# until it has been tested in game. On, the mod changes one pointer in the game's memory on your PC. An enemy your
# game removed because the host's game no longer has it, or a shared enemy you fought that died in both games, then
# stays away when your zone resets after your death or your camp rest, instead of appearing for a moment before it is
# removed.
spawn_filter=off
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
# Revive, experimental: on or off, off by default. Yours, for your own EVE: on, while you are on the death screen and
# your friend stands within 2 m of your EVE for 3 s, your game revives you where you fell, with full health and your
# recovery items refilled as at a camp. It needs the shared enemies running (shared_enemies=on, on a co-op save), and
# never happens during a boss fight on your side. In a co-op Night Operation run, on also turns your death into a 30 s
# down: your friend revives you by holding the interact key next to your EVE, or you type coop nightop revive.
revive=off
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
# Cutscene wait: on or off. Yours, as the guest: on, your game pauses while a cutscene plays in the host's game and you
# are both on one map, with the same pause as photo sync and for at most photo_freeze_max.
cutscene_wait=on
# Follow the host, as the guest, on a co-op save: ask, always or off. When the host is on another map, or more than
# 150 m from you on yours, ask shows a notice once and follow_key then takes you to the camp nearest them through the
# game's own fast travel (one of the camps you have found); always starts that travel by itself 5 s later, and
# follow_key cancels it; off does neither. With follow_key=none, only the console command coop travel host travels.
follow_host=ask
# Solid partner, experimental: on or off, off by default. Yours: on, your EVE cannot walk through your friend's ghost
# while she walks, runs or falls. The ghost lets her through while it overlaps her, while your feet are 60 cm or more
# apart in height, after 2 s of contact (until you are 50 cm apart) and while your friend is down. A dodge into it
# stops at it. Enemies, NPCs and the camera pass through it.
collide=off
# The co-op menu: ui_scale 75 to 150 (%), ui_sounds on or off, ui_language game (the game's language) or english.
ui_scale=100
ui_sounds=on
ui_language=game
# The session chat (Enter opens it during a session): on or off. Off hides your friend's lines and sends none.
chat=on
# Mod names: on or off. On, your friend's game gets the names of the .pak mods your game loads (beyond the base game's,
# under SB/Content/Paks), so each of you is told which mods the other uses and you lack. Off sends only how many there
# are and one hash of them, and the parts of your outfit from a mod's own folder reach your friend's ghost of you as
# the base suit or not at all.
mod_names=on
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
| `follow_key` | same as `menu_key`, or `none`: as the guest, travel to the host ([Following the host](#following-the-host)) | `F7` |
| `race_key` | same, or `none`: a key that sets a [Doro race](#doro-races) checkpoint while you record a track | `F9` |
| `drift_keys` | up to 4 Unreal key names separated by spaces, or `none`: the keys held to [drift](#driving) in a race | `Gamepad_RightTrigger B` |
| `who_can_join` | `friends`, `code` or `private`: who can join a session you host (`code`: anyone with your [join code](#join-codes); `private`: only the friends you invite) | `friends` |
| `auto_coop_save` | `ask`, `always` or `off`: the [co-op saves](#co-op-saves) at the title | `ask` |
| `name_tag` | `on` or `off`: your friend's Steam name above their ghost | `on` |
| `send_rate` | `10` to `60` poses sent a second at most (a link that cannot keep up lowers it to 30 or 20 for a while: [link health](how-it-works.md#link-health-in-the-log)) | `60` |
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
| `spawn_filter` | `on` or `off`: the [spawn filter](#spawn-filter-experimental), experimental; your own, used when you are the guest; no menu row | `off` |
| `bosses` | `on` or `off`: [shared bosses](#shared-bosses-experimental), experimental; the host's value counts for both games | `on` |
| `boss_hp_scale` | `1.0` to `4.0`: the host's multiplier for a shared boss's maximum HP, used in both games | `2.0` |
| `shared_quests` | `on` or `off`: [shared quests](#shared-quests-experimental), experimental; both players need it on | `off` |
| `quest_deny` | quest names or numbers separated by spaces or commas, at most 200 characters: quests never shared; the host's value counts | empty |
| `revive` | `on` or `off`: your friend may [revive](#revive-by-your-friend-experimental) your EVE where she fell, experimental; in a co-op Night Operation run, your death is a [down](night-operation.md#down-and-revive) | `off` |
| `photo_sync` | `both`, `notice` or `off`: the [synced photo mode](#synced-photo-mode); a pause needs `both` on both PCs | `both` |
| `photo_freeze_max` | `0` (no limit) or `30` to `3600`: the longest pause your friend's photo mode holds your game in, in seconds | `600` |
| `photo_ghost` | `on` or `off`: your friend's ghost in your own photos | `on` |
| `photo_name_tag` | `on` or `off`: its name tag in your own photos | `off` |
| `cutscene_wait` | `on` or `off`: as the guest, your game [waits](#cutscene-wait) while a cutscene plays in the host's game | `on` |
| `follow_host` | `ask`, `always` or `off`: as the guest, the offer to [travel to the host](#following-the-host) | `ask` |
| `collide` | `on` or `off`: the [solid partner](#solid-partner-experimental), experimental | `off` |
| `ui_scale` | `75` to `150`: the size of the menu, the chat and the partner HUD, in percent | `100` |
| `ui_sounds` | `on` or `off`: the game's UI sounds in the menu, the chat and the partner HUD | `on` |
| `ui_language` | `game` (the game's text language) or `english` | `game` |
| `chat` | `on` or `off`: the [session chat](#session-chat); off hides your friend's lines and sends none | `on` |
| `mod_names` | `on` or `off`: the names of your `.pak` mods go to your friend, for the [notice](#shared-enemies-experimental) of the mods one of you lacks; off sends their count and hash only, and no path from a mod's own folder goes in your capture (see [Mods and CNS outfits](#mods-and-cns-outfits)); no menu row | `on` |
| `partner_bar` | `on` or `off`: the [marker](#partner-hud) over your friend's ghost; on, it carries their name instead of the name tag | `on` |
| `partner_arrow` | `on` or `off`: the arrow toward your friend when they are out of view | `on` |
| `partner_card` | `on` or `off`: your friend's card at the top left | `on` |
| `card_details` | `on` or `off`: the ping and your friend's map on the card | `on` |
| `status_overlay` | `off`, `compact` or `detailed`: the [status strip](#status-strip-above-the-card) above the card | `off` |

Rules:

- `F10` is refused because it opens the console (as does `~`). Function keys do not depend on the keyboard layout.
- Names and values ignore case, a UTF-8 BOM (Notepad) is accepted, and lines starting with `#` are comments.
- A refused value keeps its default, and `UE4SS.log` gives the reason in a `[StellarCoop] settings:` line. An unknown
  setting is ignored with a note.
- If two actions share one key, all the keys go back to their defaults: `F5` for the menu, `none` to host, `F6`, `F7`,
  `F8` and `F9`.
- A file written before `follow_key` existed that already holds `F7` for another action keeps it there: `follow_key`
  then reads `none`, with no log line.
- A file with no `race_key` line (one written before Doro races) whose other keys already use `F9`: `race_key` reads
  `none`, and `UE4SS.log` says so, for example `[StellarCoop] settings: F9 is leave_key: race_key has no key`.
  `coop race cp` still sets checkpoints.
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
  `keys: menu=F5 host=none status=F6 leave=F8 race=F9, name tag on, 60 poses a second`. Another line says when a mod
  loaded earlier binds the same key; both actions then run. The `[StellarCoop] photo sync:` line gives the photo
  settings in use.

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
  its leader's bones, only while the ghost is on screen. It collides with her outfit as in solo: it takes the collision
  asset her ponytail uses (her capture's `cloth` line, a CNS outfit's `PonyPhysics` among them), else the outfit's
  ponytail collision asset (`<body mesh>_PonytailPhysicsAsset`). If your PC lacks both, the build line says
  `outfit collision not used` and the cloth keeps the clothing asset's own collision. Only that asset's path goes over
  the network, whatever the setting. Each PC simulates the ghost it draws, so only the viewer's setting counts, and the
  strands follow the same rules as on her screen without being the same strands. If the cloth part fails, the ponytail
  is a plain part, with a note in the log.
- `dyes`: her hair colour and other material variants. Her capture also names each part's overridden materials (a
  material made at run time is sent as the asset it was made from), and the ghost puts on each one your PC has, by the
  same rules as the meshes. Dyes do not apply to a fallback mesh. Off, each part has its mesh's own colours, except a
  part on a mod's mesh, which takes its materials either way (see [Mods and CNS outfits](#mods-and-cns-outfits)).
- `effects`: her attack and skill effects. The native part reads which of 19 known effects (Niagara systems) are
  playing on her, at most 4, into four effect slots of each pose (an index into a fixed list, never a path). The ghost
  starts each effect on the part it hangs on, moves it with the slot and stops it when the slot changes, at most 8
  starts a second. A fault in the native effect read or write turns effects off until the game restarts
  (`effects off: fault ...`), and the ghost stays without them. Every 60 s with any effect activity, an
  `effects, last 60 s:` line counts those started, those over 4, unlisted reads and boxes written.
- `dyes=off` and `effects=off` also stop sending yours, so your friend's ghost of you lacks them too.

## Mods and CNS outfits

Your friend's ghost loads the meshes their capture names. What your game can draw depends on where a mod puts its
files.

A replacer mod puts its files at the path of a game asset, under `/Game/Art/Character/` or
`/Game/DLC_<n>/Art/Character/`. Your game loads its own file at that path: the mod's version if you have the same mod,
the original if you do not. A leader part (one with bones of its own) whose mesh here has other bones than theirs is
drawn on your mesh with each of its bones following theirs of the same name. A head replacer you lack still shows a
head that way: the original head, moved by the bones the two share.

An added-asset mod puts new assets in a folder of its own. CNS outfits use `/Game/OutfitMods/<name>/`, and `HD-ATOOL_P`
uses `/Game/Mods/HD-ATOOL_P/`. Your game looks up a mesh, a material or a ponytail collision asset from such a folder
only when one of your own CNS packs names that exact path. A pack names every `/Game/...` path it gives under
`OutfitPaths`, `Mesh`, `Materials`, `PonyPhysics`, `Textures` and `Value`. The native part reads your
`*.dekcns.json` files under `SB/Content/Paks/~mods` once at start and writes those paths to `coop-cns.txt`. With the
same CNS outfit installed on both PCs, the ghost wears it. A path that none of your packs names is never looked up or
loaded, even when the file is there: a mod that comes without a CNS pack, such as `HD-ATOOL_P`, always falls back.

A part that cannot be drawn on its own mesh falls back: the body to the base suit `CH_P_EVE_08`, the hair to
`EVE_HR_01`, and any other part is left out with the parts that follow it. When such a part comes from a mod's folder,
a notice names the outfit, in the menu's language, once each time their capture changes (an outfit change, or a load
in their game):

`Kaanta wears parts from mods your game cannot load: Foo_Suit, HD-ATOOL_P. They show on the base suit or are left out.`

The name is the outfit's `UniqueFitID` in your friend's CNS pack, else the last of the first two folders of the path
(`HD-ATOOL_P` for `/Game/Mods/HD-ATOOL_P/...`). Up to two names fit, then `(+n)` for the others. `coop basesuit`
gives no notice.

A part on a mod's mesh sends its overridden materials even with `dyes=off`: CNS sets an outfit's materials when it
puts the outfit on, so the mesh's own are not the outfit's. Her ponytail's collision asset goes too (the `cloth` look
uses it), so a CNS outfit's `PonyPhysics` reaches the ghost.

A mod's added assets are usually missing from the game's cooked asset registry, and UE4SS's `LoadAsset` finds an
asset through that registry. When `LoadAsset` finds nothing for a path your packs name, the ghost tries
`AssetRegistryHelpers:GetAsset`, which loads by path (the way UE4SS's BPModLoaderMod loads mod actors). This step has
not been tested in game yet. The `Ghost ... built` log line says how each mod asset came:
`mod assets: <path> by GetAsset` (or `by LoadAsset`, `in memory`, `missing`), and which outfits were not shown:
`mod parts not shown: <names>`. A path your packs do not name shows as `<path> not declared by your CNS packs`.

With `mod_names=off` in `coop-settings.txt`, your capture leaves out every path outside the game's own folders: your
friend's ghost of you shows those parts on the base suit or leaves them out, and no folder or outfit name of yours
reaches them.

Not carried: CNS material settings (colours, sliders, texture options, toggles), shape keys and face morphs,
accessories that are static meshes, actors attached to EVE, and parts past 16. A pose holds about 900 leader bones in
all. When her parts have more, the capture leaves out the last leader parts and their followers until the pose fits,
and its log line ends with `<n> leaders left out, over the pose size`.

## Solid partner (experimental)

With `collide=on` (Options > Ghost > Solid partner; off by default, not tested in game yet), your EVE cannot walk
through your friend's ghost, as with an NPC in town. It is your own setting and changes nothing in your friend's game.
Only your EVE is stopped: enemies, NPCs, the camera and attacks pass through the ghost. If a game update changes her
capsule's collision, the mod falls back to a capsule that the enemies run by your PC meet too, and its build line in
`UE4SS.log` says `ours type 1`.

The ghost lets your EVE through:

- once it overlaps her by more than 1 cm, until they are more than 20 cm apart (the ghost shows your friend about one
  ping late, so it can step into you; a smaller overlap stays solid and can move you by up to 1 cm);
- while your feet are 60 cm or more apart in height (one of you on a ledge, a ladder or an elevator);
- while your EVE swims, climbs, rides a zipline or does anything but walk, run or fall;
- after 2 s of contact, until you are 50 cm apart (a friend standing in a doorway);
- while your friend is down, or their vitals have not arrived for 3 s;
- while the ghost is hidden.

A dodge into the ghost stops at it, where it would pass through an enemy. Turn it off in the menu if it gets in your
way (see [troubleshooting.md](troubleshooting.md#stuck-at-a-doorway-with-the-solid-partner)). `coop status` shows
`collide=` on the ghost's line.

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
| [Following the host](#following-the-host) (guest) | `<host> is in <map>. Press F7 to travel to the camp nearest them.`, `Following <host> in 5 s. Press F7 to stay.`, `Travelling to <host>.`, `No camp you have found is near <host>.`, `You cannot travel now. Try again in a moment.` or `The travel did not start. UE4SS.log says why.` |
| Your friend down | `<name> is down. Stand next to them for 3 s to revive them.`, then `You revived <name>.` when they get up next to you |
| You down, with your friend alive on your map | `<name> can revive you: wait, or respawn at a camp.`, then `Revived by <name>.` ([revive](#revive-by-your-friend-experimental)) |
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
| Your friend's `.pak` mods differ from yours, once a session | `<name> uses mods you don't have: <mods>. ...`, `<name> uses other versions of mods you have: <mods>. ...` or `<name> loads other .pak mods than you (<n> there, <n> here). ...`; see [Shared enemies](#shared-enemies-experimental) |
| Shared enemies started, stopped, or waiting for something | See [Shared enemies](#shared-enemies-experimental) |
| Same place moving enemies, or stopped | See [Same place](#same-place-experimental) |
| Shared quests on, off or waiting for a co-op save, and quest steps that wait or that were made apart | See [Shared quests](#shared-quests-experimental) |
| Night Operation: a partner's run starting, a partner who cannot join, the points a run gave | See [night-operation.md](night-operation.md#the-co-op-run) and [the reward shop](night-operation.md#the-reward-shop) |

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

- Steam: `mod=<version> proto=14 steam=<waiting|ready>`, then the Steam ID, app id, game build, overlay, relay
  availability and callback counts.
- Link: `link=<none|host|guest> lobby=<id>`, with `pending=1` while a lobby call runs, `held=<lobby>` for an invite held
  and `rejoin=<n>/3` while rejoining. While you host, a `code=<join code|none> refused=<n>` line follows: the join code
  (`none` unless the lobby was made with `host code`) and the number of players refused for the rest of this lobby; then
  a `pending=<SteamID> <name>` line for a player who is not your Steam friend and waits for your answer. Then a
  `peer=...` line per lobby member (handshake, lost flag, RTT), a `friend=<linked 0|1> <lost 0|1> <name>` line, after a
  [coop mark](#coop-mark) a `mark=<n> ours: <text>` or `mark=<n> from <name>: <text>` line (no `: <text>` for a mark
  with no text), a `mate=<12 numbers>` line with your friend's HP, shield, Beta, Burst and Tachy for the partner card
  (while their last reading is under 3 s old; your own during `coop loopback`), a `life=<state> <hp>` line with your
  own EVE's life state (1 or 6 alive, 3 to 5 dying or dead) and HP for the revive, a `night=<line>` line with your
  friend's last Night Operation line while a session holds, and the last 8 notices as `notice=<n> <text>`. While you
  host, `camps?=<id>` is the guest's last request for the camps nearest you; as the guest, `camps=<id> <answer>` is the
  host's last answer ([Following the host](#following-the-host)).
- Pose path: `engine=on` (then `loopback=on <delay> <jitter> <loss>` or `loopback=waiting` until EVE's capture comes,
  `record=on`, `replay=on`, `remote=<generation> <count> <loopback|replay|peer>`), or `engine=off reason=<why>`; then
  `warp=<idle|busy> me=<n>` (a respawn or a warp under way, and your EVE's id, for the revive), `travel=<state>
  travel_calls=<n>` (the last travel's state: `idle`, `pending`, `warping`, `arrived` or `refused:<why>`, and the travel
  requests handled so far), `anim=<state> anim_id=<n>` (the last `coop emote` clip the native part took and what
  became of it: `idle`, `playing`, `ended`, `ended:weight`, `stopped`, `refused:<why>` or `fault`, see
  [Emotes](#emotes-coop-emote)), `items=<ask> <count>` or `items=<ask> none <why>` (the answer to
  [`coop gift`](#cut-mailbox-coop-gift)'s last inventory read, by its number; why is `unpinned`, `noeve`, `nomanager`,
  `nobucket` or `unread`), and `nightop=on` or `nightop=rule` while the probe's poller runs.
- Save slot: `slot=<coop|main|none|unknown> index=<n|?> marker=<n|none|bad|?> saves=<coop|main|off|?>` (see
  [saves.md](saves.md#co-op-saves)). `saves=` names the save files the game uses: `main` for your own,
  `coop` for the co-op copies (`StellarBladeCoop00.sav` to `04`), `off` when the mod cannot read the file name (another
  game build, or a check failed), and `?` before the first read or once the name moved in the game's memory (no switch
  until the game restarts). `coop-link.log` logs each change as `save name: saves=<value>`, with the reason for `off`
  and `?`. After `coop off` it keeps the last value read, since the game keeps that file name until it exits.
- Co-op save copies: `convert=<idle|busy <done>/<jobs>|done|error:<why>>`, the last copy pass (`idle` before any).
- Shared enemies: `fight=on mode=<on|probe|record|replay> ...` with its counts, `fight=waiting mode=<mode> why=<what it
  waits for>`, `fight=stopped why=<why>` or `fight=off`, with `her=<state>` while a friend is linked (see [Shared
  enemies](#shared-enemies-experimental)). While it runs, the line ends with `boss=<0|1>` (a boss fight on your side),
  `battle=<n>` (enemies in battle within 30 m of your EVE) and `epoch=<zone>/<n>/<resets>` (same spawns' zone and epoch,
  and how often your own zone reset this run).
- Same place: `pilot=on piloted=<n>`, `pilot=off why=<why>`, `pilot=stopped` or `pilot=refused why=<why>` (see
  [Same place](#same-place-experimental)).
- Shared quests: `quests=off`, `quests=waiting mode=<mode> why=<friend|save|game>`, `quests=on mode=<mode>
  role=<role> partner=<on|off>` or `quests=stopped` (see [Shared quests](#shared-quests-experimental)), then the last 8
  quest notices as `quest_note=<n> <kind> <number> <name> <zone or ->` and the last `coop quests status` answer as
  `quests_status=<n> <line>` lines.
- Photo mode: `photo=<0|1|s|c> peer_photo=<0|1|s|c> frozen=<0|1> sync=<both|notice|off>`: yours and your friend's (`s`
  for selfie mode, `c` on the host while a cutscene plays: the [cutscene wait](#cutscene-wait)), whether your game holds
  the photo pause (`coop freeze` holds it too), and the `photo_sync` your friend gets (`notice` when your game cannot
  pause).
- Last event: `last=<the last coop-link.log event>`.
- Ghost: `ghost=on parts=<n> leaders=<n> basesuit=<0|1> left_out=<n> table=<generation> source=<source>
  collide=<on|off|failed>`, `ghost=waiting`, `ghost=hidden map` or `ghost=off`, plus `stray_parts=<n>` if ghost parts
  that are not this load's ghost stand in the world. Once the [solid partner](#solid-partner-experimental)'s capsule
  exists, `collide=` adds `solid=<0|1>` and `changes=`, the times it turned solid and the times each rule let your EVE
  through (`a` hidden or off, `b` overlap, `c` height, `d` movement mode, `e` 2 s of contact, `g` your friend down).

Each changed status line, except the per-peer ones, the `fight=` line, the `mate=` and `life=` lines and the `night=`
line (Night Operation's run logs each one as an `[NR]` line), also goes to `UE4SS.log` as `[StellarCoop] link: ...`.
Each load logs the save slot as `link: slot=...`.

## Files in the mod folder

Everything the mod writes stays in `Mods/StellarCoop/`, apart from the save folder files listed in
[saves.md](saves.md#what-the-mod-reads-and-writes). An install never removes these files, and
`tools/install.py --uninstall` backs them up before it removes the folder.

| File | Written by | What it is |
| --- | --- | --- |
| `coop-settings.txt` | Lua, once, then the co-op menu | Your settings (see above) |
| `coop-settings.old.txt` | Lua, at the menu's first change since the mod loaded | `coop-settings.txt` as it was before that change |
| `coop-guide.txt` | Lua, on the guide's Don't show again or a close on its last page | One line. While it exists, the [guide](#guide) does not open by itself |
| `coop-records.txt` | Lua, after a challenge or Night Operation success that beats the best kept | Your best runs, one `best_<name>=<score> <seconds>` line each (see [night-operation.md](night-operation.md#best-runs-coop-recordstxt)). Written to `coop-records.txt.tmp` first, then renamed |
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
| `coop-cns.txt` | native, at start | The assets your CNS packs declare, one `<path> <outfit>` line each (empty without CNS packs): the only paths from a mod's folder the ghost loads |
| `coop-display.txt` | Lua | The ghost Lua built for that table |
| `coop-state.txt` | Lua | Whether a save is loaded or the title screen is shown, the send rate, your photo mode and the photo settings |
| `coop-puppet.txt` | Lua | The ghost's object path, so the next Lua load can remove a ghost left standing |
| `coop-ui.txt` | Lua | The co-op UI's on-screen root, so the next Lua load (Ctrl+R) can remove it and, if the menu was open, give the game its keys back |
| `coop-say.txt` | Lua | A chat line you typed, for a moment: the native part takes and deletes it at its next pass |
| `coop-chat.txt` | native | Your friend's chat lines and race lines, for a moment: Lua takes and deletes the file within 250 ms, or within a frame while a race is armed |
| `coop-night.txt` | Lua | Your side of a Night Operation run, for a moment: the native part takes and deletes it at its next pass and sends it to your friend |
| `coop-night-<steamid>-<index>.txt` | Lua | Your Night Operation shop points on that co-op slot, one line (see [night-operation.md](night-operation.md#the-reward-shop)) |
| `coop-gift-<steamid>-<index>.txt` | Lua | Your mailbox on that co-op slot: the gifts that wait, the ones you sent that wait for an answer or come back, and the last 64 gifts taken (see [Cut mailbox](#cut-mailbox-coop-gift)) |
| `coop-gift-toast.txt` | Lua | While a gift's toast shows: its object path, so the next Lua load (Ctrl+R) can take it off |
| `coop-race.txt` | Lua | Your [Doro race](#doro-races) lines, for a moment: the native part takes and deletes the file at its next pass |
| `coop-track-<name>.txt` | Lua, on `coop race save` | A Doro race track |
| `coop-look.txt` | Lua | While the Doro look is on: EVE's object path, her main mesh's animation option before the look, the Doro's object path, the names of the parts the look hid and, once the look hid the drone's body, the drone's object path, so the next Lua load (Ctrl+R) can show both again |
| `coop-race-doros.txt` | Lua | While a race shows Doros: their object paths, so the next Lua load (Ctrl+R) can remove them |
| `coop-drive.txt` | Lua | While a race or the drive probe drives EVE: her object path and her movement's four values from before, so the next Lua load (Ctrl+R) can put them back |
| `coop-leviathan.txt` | Lua | While `coop leviathan show`, `coop gardener show` or `coop tendril show` shows a mesh or the free camera is on: the mesh actor's object path and the mesh's, the camera actor's path, the player controller's path, whether its move and look input were ignored before and the path of its view target before, so the next Lua load (Ctrl+R) can remove both and give the controller back |
| `coop-devmenu.txt` | Lua | After a `coop devmenu` row reached the game, until `coop off`: one line, so `coop off` runs `clear` and `lockswitch` even after a Lua reload (Ctrl+R) |
| `coop-wear.txt` | Lua | While `coop wear` puts a look on: your EVE's object path and, for her hair and her suit, the worn mesh's path and her own look (the mesh's path, the hair's animation Blueprint class, the hair's physics asset and the materials the game set on its slots), so the next Lua load (Ctrl+R) can give it back |

Each file shared between Lua and the native part is written in full to a `.tmp` file beside it and then renamed over it,
so neither side reads a half-written file. When the native part starts, it deletes the capture, remote, display, state,
chat and night line files, `coop-race.txt`, and any stale request or report, and writes `coop-cns.txt` again. The chat
files and `coop-race.txt` are also deleted when a session ends and when the game exits. A run without `coop no` writes
no probe file, so `nightop-probe.old.txt` can be older than the previous run.

An install and the release zip both add `Scripts/version.lua`. An install also writes `install-manifest.txt`; the
release zip adds `INSTALL.md`, `CHANGELOG.md` and `SHA256SUMS.txt`.
