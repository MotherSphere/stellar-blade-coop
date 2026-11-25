# Playing with a friend

One player hosts a session and the others join it through Steam. An online session holds 2 to 4 players, the host
included ([More than 2 players](#more-than-2-players)); the match lobbies of up to 8 players start from the
[SBO lobby](../online/lobby.md) instead. Shared enemies and your friend's EVE have their own pages,
[Shared enemies](../fight/enemies.md) and [Ghost](../online/partner.md). How the link and the features below work is in
[The Steam link](../online/steam-link-internals.md) and [Group play: how it works](../online/group-internals.md).

1. The host presses F5 and selects Host a session. The [Create a session screen](interface.md#create-a-session-screen)
   opens on the values in effect: Who can join, Players, then the session rules. Start creates a Steam lobby for as
   many players as Players says (`max_players`, 2 to 4, 4 by default), open as Who can join says:
   - Public (the default): the online session shows in Find a session for every player of your version, with your
     Steam name, region and nearest camp. No dialog opens. A player who is not your Steam friend asks to join and
     waits for your answer (see [Asking to join](#asking-to-join)).
   - Friends only: the Steam invite dialog opens. Pick your friend there. Your Steam friends who have the mod can also
     join from Find a session, from their friends list or with `coop join`.
   - Invitation: the Steam invite dialog opens and a notice gives your [join code](#join-codes). The session shows in
     no list: only the friends you invite and the players you give the code to can join.
   - Private: nobody can join, not even with an invite or a code (`Hosting a private session: nobody can join it.`).

   Friends join without asking, under Public and Invitation, is On by default: your Steam friends get in at once. Off
   makes them wait for your answer too. Each row is the same setting as on the Options page: a change there shows here
   and the other way round. Who can join, Friends join without asking and Players count for the next session you host.
   Back closes the screen without hosting. `coop host public` (or `friends`, `invitation`, `closed`) hosts at once with
   that value, without the screen.
2. Your friend accepts the invite in Steam, or selects your session in [Find a session](#finding-a-session). If their
   game is closed when they accept an invite, Steam starts it. They join once a save is loaded (EVE in a world, not on
   the title screen). Until then their game holds the invite (`Invite held: joining once your save has loaded.`). A
   newer invite replaces a held one. Host, join or leave drops it.
3. The ghost turns on automatically in both games when the session starts. Once both games have accepted each other's
   handshake, each of you sees the other's EVE where she stands, in her outfit, with their Steam name above her.

More about sessions:

- The host leads. When the host leaves, every guest leaves too (`Session ended: <host> left.`).
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
- Both players need the same protocol (29) and game build. A mismatch shows a notice on screen (see
  [Notices](interface.md#notices)).

The ghost is display only. Items, unlocks and progress are not copied between your two games, except the consumables
you send with [`coop gift`](../cutmenus/menus.md#cut-mailbox-coop-gift), which leave one co-op save and go into the other. The experimental
[shared enemies](../fight/enemies.md#shared-enemies-experimental) are on by default and run on [co-op saves](#co-op-saves) only.

Achievements follow one rule: a shared enemy you fight together counts for both of you, and nothing done without you
reaches your save. The mod never unlocks an achievement itself. Your game unlocks them from what happens in your own
world, and a shared enemy dies there only if you took part in its fight (`kill_credit` under
[shared enemies](../fight/enemies.md#shared-enemies-experimental)). An enemy or a boss your friend kills in a fight you were not in does
not die in your game, so it gives you no kill, rewards, drops, quest progress or trophy.

## Your world and your friend's

Each of you plays in your own world, from your own save. Supply boxes, collectibles, passcode doors and camps are each
player's own: a box you open stays closed and full in your friend's world until they open it there, and what is in it
goes to you only. With the [shared world](../world/objects.md) (experimental, on by default), a door, lever, switch, crane,
lift or shortcut that one of you works changes in the other's world too, on co-op saves; with it off, they move only in
the world of the player who uses them. Vendors, the request board and quest givers work for both players;
[shared quests](#shared-quests-experimental) says which quest steps are shared. Nothing one player opens, buys or picks
up is copied into the other player's game. While you are linked, the game's tutorial and record popups are off in each
game that has [`hide_popups`](settings.md#coop-settingstxt) on (the default). Each player's own values come back at
the end of the session.

## More than 2 players

A session you host holds up to `max_players` players, you included: the Players row of the Create a session screen or
of Options > Session, from 2 to 4, 4 by default. Every member sees the other members' EVEs and shares the chat. A
session of 3 or 4 players has not been tested in game yet.

- Shared enemies, the shared world and story together run between the host and one guest only, the pair: the first
  guest who got in, at once or once the host accepted her. Every other guest fights her own enemies, keeps her own
  world and plays the story in her own game. Once a session she sees `Shared enemies, the shared world and story
  together run between <host> and <pair> only. Your game keeps its own.` The host's cutscenes still pause her game
  ([Cutscene wait](#cutscene-wait)). When the pair leaves, the guest who got in first of those still in becomes the
  pair a moment later and sees `Shared enemies, the shared world and story together now run between <host> and you.`
  A guest who comes in while there is no pair sees `Shared enemies, the shared world and story together are off for
  you in <host>'s session. Your game keeps its own.`
- [Shared quests](#shared-quests-experimental) run between the host and each guest. A quest step a guest makes first
  is made in the host's game too only when she is the pair: it belongs to [story together](../story/together.md).
- The host's game asks about one joiner at a time, in the order they joined. Its question adds `Players waiting after
  this one: <n>.` to the seconds line. A joiner's 60 s start when her question is the first one. Her wait popup counts
  down the most the host's answer may take: what is left of the current question's minute, plus a minute for each
  player after that one, hers included.
- Each guest can [follow the host](#following-the-host). The host's photo mode and cutscenes pause each guest as in a
  session of 2. A guest's photo mode pauses no other game: the host sees `<name> is taking photos (no pause with more
  than 2 players).` The guest sees `<host>'s game does not pause for photos with more than 2 players.`
- The host and the pair can be [revived](#revive-by-your-friend-experimental) by any member: the nearest one alive
  within 2 m across and 1 m up or down. The down notice comes when one of them goes down on your map, on the host's
  game and the pair's. Another guest cannot be revived and gets no down notice: the revive waits for a boss fight to
  end, which her game reads from the shared fight. That fight runs within the pair only. When she goes down, she
  respawns at a camp as in a solo game.
- The [partner HUD](interface.md#partner-hud) keeps its card for the pair on the host and for the host on a guest.
  Each other member gets a row beside the card. The status line names the card's player and adds `+<n>` for the
  others, for example `Co-op: hosting Alex +2.`
- Gifts, Doro races, Night Operation runs and the PvP test are for 2 players. Past 2, each is refused with the reason,
  for example `Doro races are for 2 players at most; this session has 3`. A refused gift takes nothing from your save.
  A gift sent while you were 2 still gets its answer once a third player is in.
  Picking a Night Operation level at Roxanne's shows `Night Operation does not run in a session of more than 2
  players.` A run under way when a third player gets in ends on both games with that line. A Doro race under way
  ends the same way, with `Doro races do not run in a session of more than 2 players.`
- Once the lobby holds 3 players or more, your game starts each member's link at 30 poses a second, as in a match
  lobby. A link steps back up toward 60 after 10 s with Steam's send queue calm.
- Options > Chat holds a mute row for each other member. A muted member's chat lines stop showing on your screen for
  the game run, as with `coop mute`.

## Finding a session

Find a session, on the co-op menu's main page and on the co-op line outside a session, opens the
[Sessions screen](interface.md#sessions-screen). Its Public tab lists the Public online sessions of the players whose
mod runs your protocol and whose game runs your build. Its Friends tab lists the sessions your Steam friends host with
Public or Friends only. Neither tab shows an Invitation or Private session, a full one, one whose host you blocked on
Steam or on your [block list](#block-list), or your own.

Each row shows the host's Steam name, the region, the players (`1/4`) and the ping. The right pane adds the travel
camp nearest the host and the session rules the host has on. The screen searches when it opens, when you change tabs
and on Refresh (F, or Y on a controller), 5 s apart at least. It never searches by itself.

Select a row to join that session. A Steam friend of the host gets in at once, unless the host set Friends join
without asking to Off. Anyone else waits for the host's answer (see [Asking to join](#asking-to-join)). The console
reads the same list: `coop list public` or `coop list friends` searches, `coop list` prints the rows and
`coop join <row>` joins one (see [Session commands](../usage.md#session-commands)).

## Join codes

With Who can join set to Invitation (`who_can_join=invitation`; `code` and `private` from 0.11 and older read the same),
Start on the Create a session screen creates a lobby that shows in no list and opens the Steam invite dialog. The
notice `Hosting. Your join code is CCS-CBMH.` gives its 7-character code. The menu's Copy my code row shows it too.
Selecting it puts the code on the clipboard (`Join code CCS-CBMH copied.`). Send it to the other player, for example
in Discord. Each new lobby gets a new code.

The other player opens the menu outside a session and selects Join with a code. A text box opens where the menu was.
It works like the chat box: any keyboard layout, the game ignores its own keys, and the mod's keys do nothing.

| Key | In the code box |
| --- | --- |
| Enter | Join with the code typed, in capitals or not, with or without the dash. Other text stays in the box with `A join code is 7 letters and digits, like XXX-XXXX.`; an empty box closes. |
| Esc, or B on a [controller](interface.md#controller) | Close the box |

The box closes when a session starts, when the game pauses or shows the mouse cursor, and outside a world. The native
part checks the code: most codes with a wrong character get `That is not a join code: check its 7 characters.` (see
[online/steam-link-internals.md](../online/steam-link-internals.md#lobby-and-invites)), and a code that leads to no game gets one of the
`Could not join: ...` notices.

## Asking to join

A player who is not your Steam friend waits for your answer, whatever Who can join says. With Friends join without
asking set to Off, your Steam friends wait too. Both games show the game's own popup
([Join popups](interface.md#join-popups)). Yours plays the game's alert and asks `<name> wants to join`, with the
game's Accept and Decline buttons. Theirs shows `Joined <host>'s game. Waiting to be let in.` in the feed and a popup,
`Waiting for <host>'s answer`, with one Close button. Each popup shows the seconds left.

Your question opens on its own, maybe while you walk, fight or use the menu. Decline has the focus. For 1 s after it
shows every key, controller button and click does nothing, so a press meant for something else never answers it.

- The arrows, or the [controller](interface.md#controller)'s D-pad or left stick, move between Accept and Decline.
  Enter or A answers with the focused button. Esc, B or a right click declines. A left click on a button answers with
  that button. W, S and Space do nothing here. While the question is open, the mouse cursor shows and the game ignores
  its own keys and controller. The mod's keys do nothing.
- On the player who waits, Enter, Esc, A, B or a click on Close (after the same first second) cancels the request:
  their game leaves your lobby. Their popup closes by itself once you answer, with the game's accept sound when you let them in.
- A popup opens in a world, while the game is not paused and the chat box is closed. It closes the co-op menu as it
  opens. Until then it waits. It hides while the game pauses and comes back after.
- With no answer for 60 s, the native part refuses the player, even if the question never showed (with
  `coop ui off`, for example).
- `coop ui reset` answers an open question with Deny. On the player who waits, it hides the popup for that lobby and
  they keep waiting for your answer.
- A denied player cannot come back to that lobby. Their game shows `<host> refused the link: you were not let in` and
  leaves.
- A removed player cannot come back to any game you host: Remove also puts them on your [block list](#block-list).
  Their game shows `<host> refused the link: you were removed from this session` and leaves.
- If players you do not know keep asking, leave, then host again with Friends only or Invitation: neither shows in
  the Public tab of Find a session. An Invitation lobby gets a new code.
- A session with a player who is not your Steam friend goes through Steam's relays only, on both games, so neither
  of you learns the other's IP address. The relay route can add ping. Once such a player has been in your lobby, your
  game stays on relays only until you host again or join a friend's game.
- If Steam refuses the relays-only setting, nothing goes to that player and your game asks Steam again each second.
  After 3 refusals the link with that player stops. The host sees `<name> was refused: Steam would not set relay
  only.` A guest's game leaves with `Left <host>'s game: Steam would not set relay only.` when that player is the
  host. When it is another guest, only that link stops: `No link with <name>: Steam would not set relay only.`
- While a player who is not your Steam friend is in your session, the menu shows Remove <name>, which also blocks
  them. After a Lua reload (Ctrl+R) that row stays hidden for a player let in before the reload;
  `coop remove <SteamID>` still works.
- `coop allow <SteamID>` and `coop deny <SteamID>` answer from the console. `coop status` shows the waiting player on
  its `pending=` line, with the SteamID masked to `***` and its last 4 digits. These commands take the 4 digits too.

### Block list

Remove (the menu row or `coop remove <SteamID>`) keeps the player out of every game you host from then on, in later
lobbies and after the game restarts. Deny only refuses them for the current lobby.

- When a blocked player joins a later game of yours, the native part refuses them before any question or handshake.
  Their game shows `<host> refused the link: you cannot join this session again` and leaves. Yours shows
  `A player on your block list tried to join and was refused.` This works in a match lobby you host too. When a
  match lobby comes to you because its host left, a blocked player in it is removed at that moment.
- `coop block <SteamID>` blocks a player without a session. If that player is in the game you host, they are removed
  as well.
- `coop unblock <SteamID>` takes one player off the list and `coop unblock all` empties it. A player unblocked while
  still in your lobby is greeted again (or asked about, if not your Steam friend) at once. For a player you blocked
  in this game run, `coop unblock` also takes the 4 digits the logs show after `***`.
- For a player blocked in an earlier game run, `coop unblock` needs the full SteamID, 17 digits. The logs and the
  block list never hold it whole. Ask the player for it: their own `coop-status.txt` shows it after `steamid=` on its
  first line. Their Steam profile shows it too, in the address `steamcommunity.com/profiles/<SteamID>`, unless they
  set a custom one. While a player is in your lobby, your `coop-status.txt` has it on their `peer=` and `member=`
  lines, so you can note it before a remove.
- `coop blocked` prints how many players the list holds. It cannot name them.
- The list is `coop-blocked.txt` in the mod folder. It holds a hash of each SteamID, so the SteamIDs do not show as
  they are. The hash does not keep them secret. The salt is the same for every player. Steam has about 4 billion
  personal accounts, few enough for one PC to hash them all in a few minutes. Anyone who gets your file can list every
  SteamID on it that way, so do not share it. Keep it when you update the mod (see
  [INSTALL.md](../../INSTALL.md#update)).
- When the file is there at game start but the mod cannot read all of it (another program holds it open, for
  example), you see `Could not read the whole block list: changes to it are not saved until the game restarts.` The
  players it read stay blocked. The file stays as it is until the next game start, so no player on it is lost.
- The list applies to games you host. A game you join yourself, with a code or an invite, is up to you: you can
  still join a blocked player's game. Quick match is the exception. Your game never stays in a public match lobby with
  a player on your list: it leaves, then searches again and skips that lobby for the rest of the game run. A blocked
  player whom quick match sends to your lobby is refused. Her game searches again the same way.

## Following the host

As the guest on a co-op save, you can go where the host plays. When the host is on another map, or more than 150 m
from you on yours, one notice offers it: `<host> is in <map>. Press F7 to travel to them.` On your map the offer ends
once he is back within 100 m. Nothing changes in the host's game. This has not been tested in game yet.

- On the host's map, F7 (`follow_key`) puts your EVE where the host last stood on solid ground, facing his way, after
  the game's own fade. His game sends that point: where his EVE last walked on a floor, at most 10 s ago. F7 works at
  any distance past 5 m. Within 5 m it does nothing (a log line only). Your respawn camp stays the one you had.
- On another map, F7 asks the host's game for the 8 camps nearest his EVE. Your game travels to the first of them that
  it can use (`Travelling to <host>.`) through the game's own fast travel. Once you stand on his map, your game puts
  you where he last stood on solid ground, with no second key press and no notice. It tries for 30 s after the
  arrival.

The game's fast travel does not check whether your save has activated a camp, and activating a camp counts toward the
game's camp trophies, so the camp travel takes only a camp the mod reads as activated in your save: one the game's own
camp list would show. `coop status` lists them on its `activated=` line.

- `follow_host=ask` (the default) shows that notice. With `always`, it reads
  `Following <host> in 5 s. Press F7 to stay.` and the travel starts 5 s later unless you press F7. With `off`, nothing
  shows and F7 does nothing.
- With `follow_key=none`, no notice shows and `always` starts nothing. `coop travel host` still travels.
- The camp travel reaches only camps your save has activated, as the game's camp menu does. If the game refuses a
  camp, the mod tries the next camp of the list, 3 calls at most.
- Only the 120 camps, phone booths and tetrapods of the game's camp table that lead to one story map can be used.
  Autosave points and the camps of the developer test maps are never sent or taken.
- The travel waits while your EVE is down, while a respawn or another travel is under way, while the game is paused,
  in photo mode or in a menu (the co-op menu included), during a Night Operation run or a cutscene, during a boss fight
  on your side or while an enemy near you is in battle. It also waits for 10 s after the last travel, while you or the
  host stand in a [solo area](#solo-areas) or while the host's game loads, plays a cutscene, warps or fights a boss.
  F7 then shows `You cannot travel now. Try again in a moment.` On his map, so does no answer from his game in 10 s.
- `<host> is not on solid ground. Try again in a moment.`: his EVE jumps, climbs, swims or falls, or has not walked on
  a floor in the last 10 s.
- `No camp you have found is near <host>.` means that no camp of the host's answer could be used.
  `The travel did not start. UE4SS.log says why.` covers the other failures (see
  [troubleshooting.md](troubleshooting.md#travel-to-the-host-does-not-start)).
- The place a travel brought you to shows no notice. The host's next map change does.
- The host's F7 does not travel to a guest. After his own death it can take him back to a guest on his map
  ([Back to a friend after a death](#back-to-a-friend-after-a-death)).

## A player down

When one EVE dies, the other player keeps playing (see [online/group-internals.md](../online/group-internals.md#a-player-down)):

- With [same place](../fight/enemies.md#same-place-experimental) on and `aggro=game` (the defaults), the shared enemies near the living
  EVE fight it. While the guest is on the death screen, the host's game takes back each shared enemy that her game ran
  and that stands within 30 m of the host's EVE, and keeps it until she is up. While the host is on the death screen,
  the guest's game takes the host's enemies within 30 m of her EVE, bosses included (see
  [Whom a boss fights](../fight/enemies.md#whom-a-boss-fights)).
- While the host is down, the guest's hits on a shared boss count as long as one player stands or is in Coma. With
  every player down, the host's game drops them: the boss's HP goes back to the host's.
- A down EVE takes no part in a kill by standing near it (the 30 m of `kill_credit=together`). Its own hits and the
  enemy's record of fighting it still count.
- With both players down, nobody can revive: each respawns at a camp in their own game.

### A death during a boss fight

When your EVE falls in a shared boss fight while a friend fights on, you watch your friend instead of the death
screen, with `spectate=on` (yours, on by default; not tested in game yet). The camera follows her. You get up where you
fell when the boss dies, when it reaches its next phase or right before one of its HP scenes, with full health and
your recovery items refilled. Left and right switch to another member alive on your map. The details are in
[Down in a boss fight: spectate](../fight/enemies.md#down-in-a-boss-fight-spectate).

- In Coma, the game's Coma screen comes first: a WB Pump you carry gets you up at once. While you can watch, its camp
  respawn button starts watching instead.
- When both players are down, nobody watches. Each gets the game's death screen and respawns at a camp, which resets
  the boss in that game as in solo play.
- The friend revive and F7's way back wait during a boss fight on your side, as before.

### Back to a friend after a death

When your EVE dies while your follow target is alive on your map, the death screen shows
`<name> is alive. Press F7 to go back to them.` A guest's follow target is the host. The host's is the living guest
on his map nearest his EVE. F7 calls the game's own in-place respawn, as the revive does: you get up where you fell
with full health and your recovery items refilled. The zone does not reset. Once your EVE stands, your game puts her
where your friend last stood on solid ground, as F7 does on one map. This has not been tested in game yet.

- The offer needs your own `revive=on`, a co-op save, shared enemies running with no boss fight on your side, no Night
  Operation run and no [solo area](#solo-areas) on either side. It comes once per death. While it shows, F7 is the way
  back. At any other time F7 is the follow.
- With `follow_host=always` it reads `Going back to <name> in 5 s. Press F7 to stay.` The way back then starts by
  itself 5 s later unless you press F7. With `follow_host=off` or `follow_key=none`, no notice shows (a log line only).
- If your friend leaves, goes down or enters a solo area between your respawn and the warp, you stay up where you fell
  with no warp. `UE4SS.log` says why.
- A death within 10 s of the last respawn the mod asked for gets no offer, so a death inside a kill volume does not
  loop. The death screen's respawn then works as usual.
- Your friend's revive and F7 in the same death call the respawn once. After your friend's revive there is no warp.
- Without F7, the death screen's respawn takes you to a camp as usual, with its zone reset. As the guest, F7 then
  follows the host from there.
- In a session of more than 2 players, only the host and the pair get the offer: it needs the shared fight, which
  runs between them alone.

## Revive by your friend (experimental)

With `revive=on` (Options > Session > Friend can revive me; on by default, not tested in game yet), your friend can
revive you where you fell. On the death screen you see `<name> can revive you: wait, or respawn at a camp.` Your
friend sees `<name> is down. Stand next to them for 3 s to revive them.` Once their EVE has stood within 2 m of yours
across, and 1 m up or down, for 3 s in a row, your game calls the game's own in-place respawn on your EVE. You get up
where you fell with full health, and your recovery items are refilled as at a camp respawn. The zone does not reset.
You see `Revived by <name>.` and your friend sees `You revived <name>.` Until then the death screen's respawn works as
usual.

The revive also needs shared enemies running (`shared_enemies=on`, both on co-op saves), your friend alive on your map,
no boss fight on your side and no respawn under way. It does not run while you or your friend stand in a
[solo area](#solo-areas). Your friend's down notice waits then too. Only the downed player's setting counts.

During a co-op Night Operation run this revive and its notices stand aside: with `revive=on` the run has its own
revive, with the interact key and a 30 s limit (see [Down and revive](../online/modes/nightop.md#down-and-revive)). With
`revive=off` a death there ends the run.

## Camp rests in a shared area

Any member can rest at a camp. With the [shared world](../world/objects.md) on (the default), a rest brings the enemies
of its zone back in the game of every other member who stands in that zone. Each of those games makes the game's own
zone reset there, for its own EVE. Those members read `<name> rested at a camp. The enemies of this area are back.` A
member in another zone gets nothing. This has not been tested in game yet.

- A member who is fighting, in a cutscene, paused, in photo mode or a menu, loading, warping or down gets the reset
  once free, within 60 s. Past that she reads
  `<name> rested at a camp. This area did not reset in your game: you were busy for a minute.`
- A respawn after a death sends nothing. It resets the zone in the dead player's own game only.
- Two rests of one zone within 30 s reset it once in each game, your own rest included. Four players who rest at one
  camp together get one reset each.
- If your game counts more than 3 zone resets within 30 s after one reset the mod asked for, the mod asks for no more
  until the game restarts: `Other players' camp rests no longer reset your area until the game restarts. UE4SS.log
  says why.`
- Each player's own `shared_world` counts. Off, your rests are not sent and other players' rests leave your area as it
  is. Rests go between co-op saves only. Nothing is sent or reset in a [solo area](#solo-areas).
- In a session of more than 2 players, a guest outside the pair has no shared fight in her game. Other players' rests
  do not reset her area yet.

With the shared world off, only the host's rest brings the enemies back for both. That needs both players in one zone
within 100 m of each other with same spawns on. The host's game resets the zone. Same spawns makes the guest's
enemies follow. The guest's own rest heals her and resets her own game, then same spawns removes again each enemy the
host's game does not have. Two notices on the guest's screen say which case applied:

- `Enemies are back: the area reset in <host>'s game.` when the host's zone resets (a camp rest, or the game resetting
  the zone) while the host is alive;
- `Shared area: only <host>'s camp rest brings its enemies back.` after her own rest there.

A respawn after a death shows neither. Away from the host (another zone, more than 100 m, or same spawns off), the
guest's rest works as in solo play.

## Solo areas

The game's zone table marks some zones as places for one player: a Boss Challenge, a NIKKE stage, the training room,
the Matrix 11 demo room and the game's test zones. When a member enters one, the others read
`<name> is in <place>. Online play waits until they are back.`, for example
`Alex is in a Boss Challenge. Online play waits until they are back.` Until she stands outside it again:

- no travel goes to her or starts from her game (`You cannot travel now. Try again in a moment.`);
- no revive and no way back after a death go toward her or start from her game;
- her camp rests reset no other game. Other players' rests leave her area as it is;
- when she is the host or the pair, shared enemies, shared bosses and story together stop between the host and the
  pair, as when they stand on different maps. The shared world and shared quests go on;
- her EVE is hidden in the other games;
- a guest's game does not pause for the host's cutscenes while either of them stands in one.

Once her zone reads public again, the others read `<name> is back.`

## Known limits

- The friend's `<name> is down` notice does not know the downed player's `revive` setting, since no line carries it.
  With `revive=off` on the downed side, standing next to them does nothing.
- On one map a shared enemy keeps one HP bar at any distance: the host's hits on an enemy 500 m from the guest lower
  her copy's HP too. Its death reaches her game only if she took part in its fight (`kill_credit`).
- A boss fight that the guest starts alone can pair with the host's copy of that boss. Her boss then takes the HP of
  the host's copy.
- A revive refills the recovery items, as a camp respawn does, and the enemies keep their HP. A death resets the zone,
  a boss fight included, which is why no revive runs during a boss fight.
- The mod never moves a player to another New Game+ cycle or difficulty. When they differ, the guest gets one notice
  about the host; the host gets one about each member who differs, for example `Kaanta is on New Game+ 1 (Hard); you
  are on your first playthrough (Normal). Enemies with another max HP stay unshared.` A change of either value gives
  one more. No such notice shows in a match lobby or in the SBO lobby.
- F7 never warps you straight into another world. From another map it goes through a camp first.
- The host's F7 does not take him to a guest. Only the way back after his own death on her map does.
- No way back after a death goes toward a member on another map: respawn at a camp, then follow.
- A travel to the host while he stands on a lift or a train lands on his last ground point, which the lift or the
  train may have left.
- When the guest rests in the zone she shares with the host while he is busy (a fight, a cutscene, a menu), same
  spawns removes the enemies her rest brought back in her game. They come back in both games once his reset comes, up
  to 60 s later.
- In a session of more than 2 players, a guest outside the pair has no shared fight in her game. Other players' camp
  rests do not reset her area. She gets no offer to go back after a death either.
- Two rests of one zone within 30 s reset it once in each game.

## Co-op saves

On the title screen, once the on-screen UI has loaded (a few seconds), the mod asks whether to play on co-op copies of
your saves, while the game uses your own saves (`auto_coop_save=ask`, the default). At the mod's first run the
[guide](interface.md#guide) comes first.
[INSTALL.md: Co-op saves](../../INSTALL.md#co-op-saves) lists the choices; [saves.md](saves.md#co-op-saves) has the files
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
[Controller](interface.md#controller)) cannot answer it: after 60 s with no key, it closes as Decide later, and
`auto_coop_save=always` or `off` skips it. Choosing Continue or Load Game before the question shows loads your own
save; the question comes back at the next title screen. `coop ui reset` closes it as Decide later.

A friend's invite accepted on the title screen waits until a save loads (`Invite held: joining once your save has
loaded.`). The question then starts with `Your friend's invite waits until your save loads.` If you already answered
Play solo normally or Decide later on that title screen, it asks once more when the invite comes.

`auto_coop_save=always` makes the copies and switches to them at each title screen without asking; `off` turns the
question and the automatic copies off. Options > Saves > Co-op saves changes it at once. The result shows as a notice in
the feed (see [Notices](interface.md#notices)). While the game uses the co-op copies, the title screen shows `CO-OP SAVES` at the
top right, whatever `auto_coop_save` says, and the question does not show.

To go on with a co-op character alone, without the mod, type `coop saves export N M` twice within 10 s at the title: it
backs up your `StellarBladeSave0M.sav`, then writes the co-op copy `StellarBladeCoop0N.sav` over it, unchanged. It
refuses a co-op copy that still holds the mod's items (the two cut stimpacks, the Shock Bolt, Beta Seeds), has Shock
Bolts as the selected ammo, or names the cut Matrix XIII area as its map, its camp, its last full camp or its last
simple camp, and `coop-link.log` says what to use up, sell or switch, or to rest at a full camp (one with a phone booth)
outside the area. A co-op save that started New Game+ with any of these keeps them in a copy that playing does not
change: the export keeps refusing it. It refuses a co-op copy that names an item of the
[team shop](../world/teamshop.md) (a name that starts with `SBOTeam_`) in an item name field (`ItemAlias`), which the
inventory and a pickup left in the world use, or on a quick slot.
Some co-op saves can never be exported, since the game keeps these names in the save for good. The refusal says so for
each: one that holds rows of the Matrix XIII area's zones (names that start with `DLC02_`, kept once it has played
there), one that names Lily's quests A Second Signal or On Time ([world/lily-signal.md](../world/lily-signal.md)) and
one that names a Matrix XIII record (`Records_MX13_...` or `Ach_Album_Unlock_MX13_...`). It also refuses a developer
save that
[`coop shortcut load`](../cutmenus/menus.md#loading-one-coop-shortcut-load) wrote in co-op slot 5 (`StellarBladeCoop04.sav`, so N is 4),
played or not, since the developer's progress and cut items would land in your own save. The rules are in
[saves.md](saves.md#co-op-saves). The export has not been tested in game yet.

## Synced photo mode

When one of you enters the game's photo mode (P), the other's game pauses about half a second later and stays paused
until the photographer leaves photo mode. The paused player can open the pause menu and enter photo mode from there,
so both of you can pose for one shot. With both in photo mode, each game resumes only when both have left. The pause is
the game's own pause, held in memory only, and nothing is saved. This has not been tested in game yet.

- Both PCs need `photo_sync=both` (the default) in [coop-settings.txt](settings.md#coop-settingstxt). `notice` on either PC gives
  a notice and no pause. `off` gives neither.
- Selfie mode gives a notice only, because the game itself does not pause in selfie mode.
- The pause ends when the photographer leaves photo mode, when the connection is lost (after 10 s; it comes back if
  they are still in photo mode when they return), when either of you leaves (F8), with `coop off`, and after
  `photo_freeze_max` seconds (10 min by default) until the photographer's next photo session.
- During your own photo or selfie mode, the mod's screen is hidden (the feed, the menu, the partner HUD), and notices
  wait until it ends, then show above EVE. Your friend's ghost stays in the shot unless `photo_ghost=off`, and its name
  tag too unless `photo_name_tag=off`.
- The pause works on game build 26123051 only. On another build, or after a fault (`photo pause off: ...` in the log),
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

With [story together](../story/together.md) on, a story scene the host plays plays in the guest's game too, so she
watches it instead of waiting. The cutscene wait covers the scenes her game cannot play with him.

## Shared quests (experimental)

Shared quests carry the quest steps that the host and the guest make together into the guest's co-op save. They are
on by default and have not been tested in game yet. Back up your saves before you play a co-op save with them on
(see [saves.md](saves.md)), and keep Steam Cloud off.

They run while a friend is linked, both players play a co-op save and both have them on: Options > Saves > Shared
quests (experimental) in the co-op menu, or `shared_quests=on` in [coop-settings.txt](settings.md#coop-settingstxt). The row asks
`coop quests on` or `coop quests off` at once, and with the setting on the mod asks `coop quests on` by itself once a
load. In an online session of more than 2 players, they run between the host and each guest. Steps go from the host
to the guest, except a step the guest makes first (see below). Four times a second the
host's game reads its own quests, and when an Epic, Sub or Request quest moves (the quest starts, one of its tasks is
done, or a group of its tasks ends), it sends that quest's state to the guest. Her game makes the same step through
the game's own quest functions, at most one step every 250 ms, when both of these hold:

- she stood in the same zone as the host when the step came;
- her copy of the quest stood where the host's stood before the step.

Her game then runs the step itself: its scenes and events, the next group of tasks, the quest's completion with its
reward, and the next quest, as in solo play. Each player gets a quest's reward once, in their own game. Through shared
quests, the game can unlock a quest trophy on the guest's account only for a step made together, or for one she
forces.

A step the host makes without her (she stood in another zone, or her quest stood at another point) is never given to
her. She gets one notice, `You are behind <name> on <quest>. Finish it in your own game to share it again.`, and plays
that quest herself; once her quest stands where the host's stands, the next step made together is shared again.

A step the guest makes first goes the other way. When her quest stood where the host's last quest line stood and she
stands in his zone, her game sends the step to the host's, which makes it in his co-op save through the same quest
functions. Kill steps, item steps, steps that move the player and quests the host never shares are not sent. His game
makes her step once he is in game with no cutscene playing and the game not paused. Up to 16 of her steps wait for
that. A load on his side drops them. This is part of shared quests: it needs `shared_quests` on, whatever
`shared_story` says. A step she makes apart from him (in another zone, or from another point of the quest) stays hers:
both players see a notice, nothing is undone and the step stays in her save. Quest givers, the request board and
vendors still work for the guest.

Some steps wait in her game:

- A step whose scenes or events act in another zone waits until she stands in one of the zones they act in:
  `<name>'s step on <quest> waits until you reach <zone>.`
- A kill step waits until her own copy of the task is done: she kills the target, or a shared enemy dies in both games
  (`<quest> waits until you kill its target yourself. coop quests force <number> skips that step.`). A forced kill
  step leaves the target alive in her world.
- A task that stands for an item waits until she picks the item up in her own game. No notice comes for it;
  `coop quests status` shows `waits for your own pickup`.
- A Request the host accepted is accepted on her board too once her board offers it. Its tasks follow the host's,
  except a task that stands for an item. Then it waits until she hands it in at her own request board, where her game
  gives her the reward and takes the delivered items (`<quest> is ready: hand it in at your request board.`).
- A step that the game's tables cannot place in a zone, and that the host's game did not see happen, waits too. She
  plays it herself or forces it.

`coop quests force <number>` makes, where she stands, the step that quest holds for a kill or for a place the tables
cannot give. The number is the one in the kill notice and in `coop quests status`. The command is sent only when typed
twice for the same quest within 10 s, because the game may then unlock that quest's trophies. A step that waits for its
zone, a step that waits for her own pickup, a Request at her board and a quest the host moved without her cannot be
forced.

What is shared: the 102 quests of the game's Epic, Sub and Request types, the hidden ones included. Not shared: the
test, tutorial, collectible and helper quests (names starting with `LV_`, `TQ_`, `SQ_` and `CQ_`), the game's one
Instant quest, the Night Operation quest `Quest_WALN10_001` and failed quests. A task that stands for an item waits
for her own pickup: the 14 Requests whose hand-in takes an item away (006, 008, 010, 016, 018, 023, 024, 025, 028 and
033 to 037) and the item tasks of `Quest_Sub_005`'s second and third groups. The host's line would give her the task
without the item. The request board gives the reward without checking it. The host's `quest_deny` adds quests that
are never shared, by name or number, for example `quest_deny=Quest_Epic_14_1, Quest_Epic_14_2`. Notices and logs name
a quest by its table name, such as `Quest_Sub_017`.

When her side comes on, the host sends the state of every quest it moved while linked with her, and only those: steps
from the host's solo play are not sent. Nothing is undone in either game when the session ends; the steps her game made
stay in her co-op save once the game saves. Each player's saved world (opened doors, supply boxes, enemies killed for
good) stays their own, so an enemy the host killed out of her sight is still alive in her world. Both saves should be
on the same New Game Plus cycle: other cycles have not been tested. A notice says when they differ (see
[Known limits](#known-limits)).

Each co-op slot keeps a record beside it in your save folder, `StellarCoopQuests0N.txt` (N the slot), which notes the
steps shared with each friend, as host and as guest. It is a text file, which Steam Cloud does not sync. Without it,
sharing goes on from where both games stand.

`coop quests status` answers with the `quests=` line and writes the whole status into `UE4SS.log` as
`quests_status=<n> ...` lines: the role, the zone, how many steps her game made and how many the game refused, and for
each quest that waits, why (`waits for its zone <zone>`, `waits for your own kill`, `waits for your own pickup`,
`hand it in at your board`, `not on your board yet`, `unseen by the host`, `behind the host, not shared`, `ahead of
the host`), with the quest's number.
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
