# Playing with a friend

One player hosts a session and the other joins it through Steam. Shared enemies and your friend's EVE have their own
pages, [Shared enemies](shared-enemies.md) and [Ghost](ghost.md). How the link and the features below work is in
[The Steam link](internals/steam-link.md) and [Group play: how it works](internals/group-play.md).

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
- Both players need the same protocol (19) and game build. A mismatch shows a notice on screen (see
  [Notices](interface.md#notices)).

The ghost is display only. Items, unlocks and progress are not copied between your two games, except the consumables
you send with [`coop gift`](cut-scenes-and-menus.md#cut-mailbox-coop-gift), which leave one co-op save and go into the other. The experimental
[shared enemies](shared-enemies.md#shared-enemies-experimental) are on by default and run on [co-op saves](#co-op-saves) only.

Achievements follow one rule: a shared enemy you fight together counts for both of you, and nothing done without you
reaches your save. The mod never unlocks an achievement itself. Your game unlocks them from what happens in your own
world, and a shared enemy dies there only if you took part in its fight (`kill_credit` under
[shared enemies](shared-enemies.md#shared-enemies-experimental)). An enemy or a boss your friend kills in a fight you were not in does
not die in your game, so it gives you no kill, rewards, drops, quest progress or trophy.

## Your world and your friend's

Each of you plays in your own world, from your own save. Supply boxes, collectibles, passcode doors and camps are each
player's own: a box you open stays closed and full in your friend's world until they open it there, and what is in it
goes to you only. Levers, lifts, doors and puzzles move only in the world of the player who uses them, so your friend's
EVE may ride a lift that stays down on your screen. Vendors, the request board and quest givers work for both players;
[shared quests](#shared-quests-experimental) says which quest steps are shared. Nothing one player opens, buys or picks
up is copied into the other player's game.

## Join codes

With Options > Session > Who can join set to With a code (`who_can_join=code`), Host a session creates a lobby that
does not show in your friends' lists, and no invite dialog opens. The notice `Hosting. Your join code is CCS-CBMH.`
gives its 7-character code. The menu's Copy my code row shows it too, and selecting it puts it on the clipboard
(`Join code CCS-CBMH copied.`). Send it to the other player, for example in Discord. Each new lobby gets a new code.

The other player opens the menu outside a session and selects Join with a code. A text box opens where the menu was.
It works like the chat box: any keyboard layout, the game ignores its own keys, and the mod's keys do nothing.

| Key | In the code box |
| --- | --- |
| Enter | Join with the code typed, in capitals or not, with or without the dash. Other text stays in the box with `A join code is 7 letters and digits, like XXX-XXXX.`; an empty box closes. |
| Esc, or B on a [controller](interface.md#controller) | Close the box |

The box closes when a session starts, when the game pauses or shows the mouse cursor, and outside a world. The native
part checks the code: most codes with a wrong character get `That is not a join code: check its 7 characters.` (see
[internals/steam-link.md](internals/steam-link.md#lobby-and-invites)), and a code that leads to no game gets one of the
`Could not join: ...` notices.

A player who is not your Steam friend waits for your answer, whatever Who can join says. Their game shows
`Joined <host>'s game. Waiting to be let in.` Yours shows a question in the middle of the screen, `<name> wants to
join`, with Accept and Deny. It opens on its own, maybe while you walk or use the menu. Deny has the focus, and for
1 s after it shows every key does nothing, so keys pressed for something else never answer it.

- The Up and Down arrows move between Accept and Deny, Enter answers, and Esc denies. W, S, Space and the
  [controller](interface.md#controller) do nothing here. While the question is open, the game ignores its own keys and the mod's
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

## Following the host

As the guest on a co-op save, you can go where the host plays through the game's own fast travel. When the host is on
another map, or more than 150 m from you on yours, one notice offers it:
`<host> is in <map>. Press F7 to travel to the camp nearest them.` F7 (`follow_key`) asks the host's game for the 8
camps nearest their EVE, and your game travels to the first of them that it can use (`Travelling to <host>.`). Nothing
changes in the host's game. This has not been tested in game yet.

In this version the travel is off until it has been tested in game: no offer shows and F7 shows
`The travel did not start. UE4SS.log says why.` The game's fast travel does not check whether your save has activated a
camp, and activating a camp counts toward the game's camp trophies, so the travel takes only a camp the mod reads as
activated in your save: one the game's own camp list would show. `coop status` lists them on its `activated=` line.
The rest of this section describes the travel as built.

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

## A player down

When one EVE dies, the other player keeps playing (see [internals/group-play.md](internals/group-play.md#a-player-down)):

- With [same place](shared-enemies.md#same-place-experimental) on and `aggro=game` (the defaults), the shared enemies near the living
  EVE fight it. While the guest is on the death screen, the host's game takes back each shared enemy that her game ran
  and that stands within 30 m of the host's EVE, and keeps it until she is up. While the host is on the death screen,
  the guest's game takes the host's common enemies within 30 m of her EVE. Bosses stay the host's.
- While the host is down, the guest's hits on the host's bosses do not count, and the boss's HP goes back to the
  host's.
- A down EVE takes no part in a kill by standing near it (the 30 m of `kill_credit=together`). Its own hits and the
  enemy's record of fighting it still count.
- With both players down, nobody can revive: each respawns at a camp in their own game.

## Revive by your friend (experimental)

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

## Camp rests in a shared area

Either player can rest at a camp. While both play in one zone within 100 m of each other with same spawns on, only the
host's rest brings the enemies back for both: the host's game resets the zone, and same spawns makes the guest's
enemies follow. The guest's own rest heals her and resets her own game, then same spawns removes again each enemy the
host's game does not have. Two notices on the guest's screen say which case applied:

- `Enemies are back: the area reset in <host>'s game.` when the host's zone resets (a camp rest, or the game resetting
  the zone) while the host is alive;
- `Shared area: only <host>'s camp rest brings its enemies back.` after her own rest there.

A respawn after a death shows neither. Away from the host (another zone, more than 100 m, or same spawns off), the
guest's rest works as in solo play.

## Known limits

- The friend's `<name> is down` notice does not know the downed player's `revive` setting, since no line carries it.
  With `revive=off` (the default) on the downed side, standing next to them does nothing.
- On one map a shared enemy keeps one HP bar at any distance: the host's hits on an enemy 500 m from the guest lower
  her copy's HP too. Its death reaches her game only if she took part in its fight (`kill_credit`).
- A boss fight that the guest starts alone can pair with the host's copy of that boss. Her boss then takes the HP of
  the host's copy.
- A revive refills the recovery items, as a camp respawn does, and the enemies keep their HP. A death resets the zone,
  a boss fight included, which is why no revive runs during a boss fight.

## Co-op saves

On the title screen, once the on-screen UI has loaded (a few seconds), the mod asks whether to play on co-op copies of
your saves, while the game uses your own saves (`auto_coop_save=ask`, the default). At the mod's first run the
[guide](interface.md#guide) comes first.
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
Bolts as the selected ammo, or names the cut Matrix XIII dungeon as its map, its camp, its last full camp or its last
simple camp, and `coop-link.log` says what to use up, sell or switch, or to rest at a full camp (one with a phone booth)
outside the dungeon. A co-op save that started New Game+ with any of these keeps them in a copy that playing does not
change: the export keeps refusing it. It also refuses a developer save that
[`coop shortcut load`](cut-scenes-and-menus.md#loading-one-coop-shortcut-load) wrote in co-op slot 5 (`StellarBladeCoop04.sav`, so N is 4),
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

## Shared quests (experimental)

Shared quests carry the quest steps that the host and the guest make together into the guest's co-op save. They are
off by default and have not been tested in game yet. Back up your saves before you turn them on (see
[saves.md](saves.md)), and keep Steam Cloud off.

They run while a friend is linked, both players play a co-op save and both have them on: Options > Saves > Shared
quests (experimental) in the co-op menu, or `shared_quests=on` in [coop-settings.txt](settings.md#coop-settingstxt). The row asks
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
