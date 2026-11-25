# Settings and files

The files the mod reads and writes in the game's save folder, outside `Mods/StellarCoop/`, are listed in
[Saves](saves.md#what-the-mod-reads-and-writes).

## coop-settings.txt

The mod writes `Mods/StellarCoop/coop-settings.txt` with the defaults when the file is missing. After that, only the
[co-op menu](interface.md#co-op-menu) changes it, one line at a time, and keeps the file as it was before its first change since
the mod loaded as `coop-settings.old.txt`. The release zip does not include the file, and an install neither adds nor
removes it (`tools/install.py --uninstall` backs it up with the folder, then removes it). The file is read when the mod
loads (game start, or Ctrl+R). Delete it to get the defaults back.

The file the mod writes:

```
# StellarCoop settings, read when the mod loads (game start, or Ctrl+R). The co-op menu (menu_key) changes them too,
# one line at a time, and keeps the file as it was as coop-settings.old.txt. Delete this file to get the defaults back.
# Keys: F1 to F12 except F10, optionally with Shift+, Ctrl+ or Alt+ in front (for example Shift+F7). menu_key opens
# the co-op menu, whose first row hosts; host_key hosts at once, or none. follow_key travels to the host (follow_host
# below), or none. race_key drops a checkpoint while you record a race track (coop race record). bike_key gets EVE on
# the bike or off it (bike below), or none. gun_key brings the rifle out or puts it away (gun_mode below), or none.
# emote_key, held, opens the emote wheel; releasing it plays the emote you point at; or none.
menu_key=F5
host_key=none
status_key=F6
leave_key=F8
follow_key=F7
race_key=F9
bike_key=F3
gun_key=F4
emote_key=F2
# The emote wheel on a controller: dpad_left (D-pad Left held 0.3 s opens it, its release plays) or off.
emote_pad=dpad_left
# The keys you hold to drift in a Doro race: Unreal key names separated by spaces (at most 4), or none. Steering hard
# at speed drifts too, with no key. The defaults are R2 on a pad (it still picks up items in reach, as outside a race)
# and B on the keyboard, which Stellar Blade leaves free.
drift_keys=Gamepad_RightTrigger B
# The bike: on or off, on by default. On, the mod keeps Stellar Blade's own bike loaded. bike_key, D-pad Right held 1 s
# on a pad or the console command coop bike puts EVE on it or takes her off, on any save. The bike stays where she gets
# off: its place is kept for each save, in the mod folder. Off gets her off the bike, removes her parked bike from
# every world (its place stays), hides the other players' parked bikes and frees the bike's files. bike_pose, a test
# of two ways to show EVE's riding pose, read at each mount: rig (a hidden copy of her plays the pose, her body
# follows it) or hold (the pose plays on EVE herself, kept above the game's own animations). rig by default.
bike=on
bike_pose=rig
# Gun mode: on or off, on by default. On, gun_key or a tap of D-pad Right gives EVE the NIKKE rifle on any save, or
# puts it away. Off, gun mode does nothing. Both are read when the mod loads.
gun_mode=on
# Who can join a session you host: public (any player of your version, from Find a session), friends (your Steam
# friends, from their friends list or the Friends tab of Find a session), invitation (the friends you invite or anyone
# you give your join code to; the co-op menu shows and copies it) or closed (nobody; Private in the co-op menu). A
# player who is not your Steam friend waits until you accept or deny them. friends_ask, with public or invitation: off
# (your Steam friends join at once) or on (they wait for your answer too). max_players: 2 to 4, the players a session
# you host holds, you included. Only you and your first guest share enemies, the world and the story.
who_can_join=public
friends_ask=off
max_players=4
# Co-op saves, the co-op copies of your saves (StellarBladeCoop00.sav to 04.sav): ask (a question on the title
# screen), always (the copies at every title, no question) or off (no copies; the manual co-op slot that
# StellarCoopSlot.txt names is then the only co-op save).
auto_coop_save=ask
# Your friend's Steam name above her ghost: on or off.
name_tag=on
# Poses sent to your friend a second: 10 to 60.
send_rate=60
# What the ghost shows, each on or off and on unless set here: cloth (her ponytail swings as in solo; it sends
# nothing), dyes (hair colours and material variants), effects (her attack and skill effects), drone (her drone),
# sounds (her steps, voice, swings and hits) and faces (her eyes, face and shape keys). Each one but cloth also stops
# sending yours when off.
# For example: dyes=off
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
# Spawn filter, experimental, yours, used when you are the guest and the host has same_spawns=on: on or off, on by
# default, not tested in game yet. On, the mod changes one pointer in the game's memory on your PC. An enemy your
# game removed because the host's game no longer has it, or a shared enemy you fought that died in both games, then
# stays away when your zone resets after your death or your camp rest, instead of appearing for a moment before it is
# removed.
spawn_filter=on
# Shared bosses, experimental, the host's for both games: on or off. On, a boss or an Alpha Naytiba that both games
# hold shares one HP bar and one death, as a common enemy does. With same_place=on, aggro decides whom it fights.
# boss_hp_scale, the host's too, multiplies a shared boss's maximum HP in place of enemy_hp_scale, from 1.0 (no change)
# to 4.0.
bosses=on
boss_hp_scale=2.0
# boss_finish, the host's: first (the first finisher press on any screen counts) or host (the host's press only).
boss_finish=first
# Shared flinches and stagger resistance, experimental, the host's for every game: on or off, on by default, not
# tested in game yet. hit_reactions: a light hit that makes a shared enemy flinch on one screen makes it flinch on the
# other screens too. stagger_resist: after a shared enemy reacts to hits from two or more players, light hits stop
# making it flinch for a short time. That time grows by 1.5 s for each extra player, 6 s at most.
hit_reactions=on
stagger_resist=on
# Shared quests, experimental: on or off, on by default. On, while you and your friend both play a co-op save, a
# quest step the host makes while you stand in the same zone, with that quest at the same point in your game, is made
# in your game too (Epic, Sub and Request quests). A step made without you is never given to you. As the guest, a
# step you make first in the host's zone, with that quest where his stands, is made in his game too (not a kill, item
# or warp step). A kill step waits for your own kill. A step that stands for an item waits for your own pickup. A
# Request waits until you hand it in at your own request board. quest_deny, the host's: quests never shared, by name
# or number, separated by spaces or commas (for example quest_deny=Quest_Epic_14_1).
shared_quests=on
quest_deny=
# Shared world, experimental: on or off, on by default, not tested in game yet. On, while you and your friend both
# play a co-op save and both have it on, a door, lever, switch, crane, lift or shortcut that one of you works through
# the game changes in the other's game too, at once or, for most of them, when that zone next loads. Chests, supply
# boxes, collectibles and anything that gives an item stay each player's own, and the doors the main story opens move
# with quest steps only. A camp rest also brings the enemies of its area back in each other player's game there.
# Off, your changes and rests are not sent and other players' are not made in your game.
shared_world=on
# Story together, experimental: on or off, on by default, not tested in game yet. On, while you and your friend both
# play a co-op save and both have it on, a story scene the host plays (a cutscene or a talk) plays in the guest's game
# too, with the host's choices, QTE results and skips. A story trip the host starts, such as Lily's warp, takes the
# guest along. A scene the guest's game cannot play keeps the cutscene wait. Off, the host's scenes are not sent and
# none plays in your game.
shared_story=on
# Revive, experimental: on or off, on by default. Yours, for your own EVE: on, while you are on the death screen and
# your friend stands within 2 m of your EVE for 3 s, your game revives you where you fell, with full health and your
# recovery items refilled as at a camp. It needs the shared enemies running (shared_enemies=on, on a co-op save), and
# never happens during a boss fight on your side. In a co-op Night Operation run, on also turns your death into a 30 s
# down: your friend revives you by holding the interact key next to your EVE, or you type coop nightop revive.
revive=on
# Spectate, yours: on or off. Down in a shared boss fight, you watch a friend until the boss falls or changes phase.
spectate=on
# Synced photo mode: while your friend is in photo mode, your game pauses. both: pause and be paused (both PCs need
# both), notice: a notice only, off: nothing. photo_freeze_max: the longest pause in seconds, 30 to 3600, or 0 for no
# limit. photo_ghost: your friend's ghost in your own photos; photo_name_tag: its name tag in them. photo_pause,
# experimental: full (photo mode stops your whole game, as without the mod) or scenery (the game's own experimental
# method: enemies, combat and shared enemies stay stopped while animations, cloth and effects go on moving), from your
# next photo mode.
photo_sync=both
photo_freeze_max=600
photo_ghost=on
photo_name_tag=on
photo_pause=full
# Cutscene wait: on or off. Yours, as the guest: on, your game pauses while a cutscene plays in the host's game and you
# are both on one map, with the same pause as photo sync and for at most photo_freeze_max.
cutscene_wait=on
# Follow the host, as the guest, on a co-op save: ask, always or off. When the host is on another map, or more than
# 150 m from you on yours, ask shows a notice once. follow_key then takes you to where the host last stood on solid
# ground: at once on his map, from another map through the game's own fast travel to the camp nearest him first (one
# of the camps you have found). always starts that travel by itself 5 s later unless you press follow_key; off does
# neither. On the death screen, with revive=on and a friend alive on your map, follow_key takes you back to that
# friend (always: by itself after 5 s). With follow_key=none, only the console command coop travel host travels.
follow_host=ask
# Solid partner, experimental: on or off, on by default. Yours: on, your EVE cannot walk through your friend's ghost
# while she walks, runs or falls. The ghost lets her through while it overlaps her, while your feet are 60 cm or more
# apart in height, after 2 s of contact (until you are 50 cm apart) and while your friend is down. A dodge into it
# stops at it. Enemies, NPCs and the camera pass through it.
collide=on
# The co-op menu: ui_scale 75 to 150 (%), ui_sounds on or off, ui_language game (the game's language) or english.
ui_scale=100
ui_sounds=on
ui_language=game
# The session chat (Enter opens it during a session or in the PvP lobby): on or off. Off hides your friend's lines
# and sends none.
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
status_overlay=compact
# Day and night: on or off, on by default. On, the sky follows one clock shared by every player: one real hour is one
# game day, with the night from about :52 to :12 past each hour (UTC). Off gives each map Stellar Blade's own light.
daynight=on
# Shortcut saves, a test tool: on or off, on by default. On, coop shortcut load <map> <1-4> writes one of the game's
# cut developer saves as your co-op slot 5 (StellarBladeCoop04.sav, backed up first), without its achievement list.
# A Steam achievement it still unlocks cannot be taken back: use it only on a Steam account whose achievements do not
# matter (docs/usage.md, Cut Load Shortcut saves).
shortcut_load=on
# PvP test, a test tool: on or off, on by default. On, coop pvp on starts it while you and your friend both play a
# co-op save with shared_enemies=off. A stand-in enemy follows your friend's ghost in your game, and your hits on it
# take HP from your friend's EVE in their game, down to 1 HP.
pvp_spike=on
# SBO lobby: on or off, on by default. On, the recruiter's Join saves the co-op game and opens the PvP lobby in Xion,
# and each co-op save is copied before the game rewrites it (the 10 newest kept per slot).
sbo_lobby=on
# Online tab: on or off, on by default. On, the pause menu gets an Online tab after Settings. RB on Settings (E on
# the keyboard) or a click on the tab closes the pause menu and opens the co-op menu.
pause_tab=on
# Popups during online play: on or off, on by default. On, the game's tutorial popups and record popups are off while
# you play online with at least one other player. Your own values come back when you leave. The game's settings file
# keeps them the whole time. Turn one on in the game's Settings during online play and it stays on.
hide_popups=on
# Score attack: on or off, on by default. On, you play each round of a score attack match in the SBO lobby. Off, you
# sit out its rounds.
scoreattack=on
# Fishing tournament: on or off, on by default. On, you fish in each tournament the host of your online session starts
# with coop fish start. Off, you sit out its tournaments. As the host you cannot start one.
fishing=on
# Doro races in matches: on or off, on by default. On, you race each round of a Doro race match in the SBO lobby.
# Off, you sit out its rounds. Doro races in an online session do not read it.
race_match=on
# Photo hunt: on or off, on by default. On, you photograph the targets of each photo hunt the host of your
# online session starts with coop photohunt start. Off, you sit out its rounds. As the host you cannot start one.
photohunt=on
```

| Setting | Values | Default |
| --- | --- | --- |
| `menu_key` | `F1` to `F12` except `F10`, with at most one of `Shift+`, `Ctrl+` or `Alt+` in front | `F5` |
| `host_key` | same, or `none`: a key that hosts at once, without the menu | `none` |
| `status_key` | same as `menu_key` | `F6` |
| `leave_key` | same as `menu_key` | `F8` |
| `follow_key` | same as `menu_key`, or `none`: as the guest, travel to where the host last stood on solid ground ([Following the host](playing-with-a-friend.md#following-the-host)); on the death screen, go back to a living friend on your map ([Back to a friend after a death](playing-with-a-friend.md#back-to-a-friend-after-a-death)) | `F7` |
| `race_key` | same, or `none`: a key that sets a [Doro race](../online/modes/race.md) checkpoint while you record a track | `F9` |
| `bike_key` | same, or `none`: a key that puts EVE on the [bike](../vehicles/bike.md) or takes her off it | `F3` |
| `drift_keys` | up to 4 Unreal key names separated by spaces, or `none`: the keys held to [drift](../online/modes/race.md#driving) in a race or on the [bike](../vehicles/bike.md#riding) | `Gamepad_RightTrigger B` |
| `bike` | `on` or `off`: the [bike](../vehicles/bike.md), on any save; off takes EVE off the bike, removes it from her, takes her parked bike out of every world (its place is kept), hides the other players' parked bikes and frees its loaded files | `on` |
| `bike_pose` | `rig` or `hold`: how EVE's riding pose shows on the [bike](../vehicles/bike.md), a test of two ways until one is kept. `rig`: a hidden copy of her plays the pose and her body follows it. `hold`: the pose plays on EVE herself, kept above the game's own animations. Read at each mount. Options, Controls, Riding pose (test): Hidden copy or On EVE | `rig` |
| `gun_key` | same, or `none`: a key that brings the [gun mode](../fight/gunmode.md) rifle out or puts it away; read when the mod loads | `F4` |
| `gun_mode` | `on` or `off`: [gun mode](../fight/gunmode.md); off, its key and D-pad Right tap do nothing; read when the mod loads. Its other `gun_` lines are test lines, listed on its page | `on` |
| `pause_tab` | `on` or `off`: the [Online tab](interface.md#pause-menu) after Settings in the game's pause menu, which opens the co-op menu. Off, RB on Settings goes to Equipment as in the game. Options, Controls, Online tab in the pause menu; it applies from the next pause menu | `on` |
| `who_can_join` | `public`, `friends`, `invitation` or `closed`: who can join an online session you host. `public`: any player of your version, who finds it in the session list. `friends`: your Steam friends. `invitation`: the friends you invite or anyone with your [join code](playing-with-a-friend.md#join-codes). `closed`: nobody (Private in the co-op menu). The words `code` and `private` from 0.11 and older read as `invitation`; the file keeps them | `public` |
| `friends_ask` | `on` or `off`, with `public` or `invitation`: `on` makes your Steam friends wait for your answer like other players. The co-op menu shows it as Friends join without asking, On while `friends_ask=off` | `off` |
| `max_players` | `2` to `4`: the players an online session you host holds, you included (Players on the Options page and the Create a session screen), from the next session you host. Past 2, shared enemies, the shared world and story together run between you and one guest only ([More than 2 players](playing-with-a-friend.md#more-than-2-players)) | `4` |
| `auto_coop_save` | `ask`, `always` or `off`: the [co-op saves](playing-with-a-friend.md#co-op-saves) at the title | `ask` |
| `name_tag` | `on` or `off`: your friend's Steam name above their ghost | `on` |
| `send_rate` | `10` to `60` poses sent a second at most (a link that cannot keep up lowers it to 30 or 20 for a while: [link health](../online/steam-link-internals.md#link-health-in-the-log)) | `60` |
| `cloth` | `on` or `off`: her ponytail as cloth on the ghost you see | `on` |
| `dyes` | `on` or `off` | `on` |
| `effects` | `on` or `off` | `on` |
| `drone` | `on` or `off`: her drone beside the ghost you see. Off also stops sending yours | `on` |
| `sounds` | `on` or `off`: her steps, voice, swings and hits played where her game played them. Off also stops sending yours | `on` |
| `faces` | `on` or `off`: her eyes, face and shape keys move on the ghost you see. Off also stops sending yours | `on` |
| `shared_enemies` | `on` or `off`: [shared enemies](../fight/enemies.md#shared-enemies-experimental), experimental | `on` |
| `fight_chars` | `auto` (every common enemy), or at most 16 enemy character ids, whole numbers separated by spaces | `auto` |
| `guest_kills` | `at_once` or `confirmed`: as the guest, whether an enemy your hit kills dies at once on your screen or waits for the host's game (see [shared enemies](../fight/enemies.md#shared-enemies-experimental)) | `at_once` |
| `enemy_hp_scale` | `1.0` to `4.0`: the host's multiplier for a shared enemy's maximum HP, used in both games | `1.35` |
| `enemy_balance_scale` | `1.0` to `4.0`: the host's multiplier for a shared enemy's balance gauge, used in both games | `1.15` |
| `kill_credit` | `together` or `fought`: when a shared enemy dies in your game, with its rewards and achievements: you hit it, it targeted you, or (`together` only) you stood within 30 m when it died (see [shared enemies](../fight/enemies.md#shared-enemies-experimental)) | `together` |
| `same_place` | `on` or `off`: [same place](../fight/enemies.md#same-place-experimental), experimental; the host's value counts for both games | `on` |
| `hit_reactions` | `on` or `off`: [shared flinches](../fight/enemies.md#flinches-and-stagger-resistance), experimental; the host's value counts for every game | `on` |
| `stagger_resist` | `on` or `off`: [stagger resistance](../fight/enemies.md#flinches-and-stagger-resistance), experimental; the host's value counts for every game | `on` |
| `aggro` | `game` or `host`: with same place, whether each enemy fights the player who hit it last (or else the nearer one) or the host only; the host's value counts for both games | `game` |
| `same_spawns` | `on` or `off`: [same spawns](../fight/enemies.md#same-spawns-experimental), experimental; the host's value counts for both games | `on` |
| `enemy_extra` | `0` to `3`: [extra enemies](../fight/enemies.md#extra-enemies-experimental) for each common enemy, experimental, with same spawns only; the host's value counts for both games | `0` |
| `spawn_filter` | `on` or `off`: the [spawn filter](../fight/enemies.md#spawn-filter-experimental), experimental; your own, used when you are the guest; no menu row | `on` |
| `bosses` | `on` or `off`: [shared bosses](../fight/enemies.md#shared-bosses-experimental), experimental; the host's value counts for both games | `on` |
| `boss_hp_scale` | `1.0` to `4.0`: the host's multiplier for a shared boss's maximum HP, used in both games | `2.0` |
| `boss_finish` | `first` or `host`: whose [finisher](../fight/enemies.md#the-finisher) ends a shared boss, the first press on any screen or the host's only; the host's value counts for both games, from the next start of shared enemies. Options, Combat, Boss finisher (host's) | `first` |
| `shared_quests` | `on` or `off`: [shared quests](playing-with-a-friend.md#shared-quests-experimental), experimental; both players need it on | `on` |
| `quest_deny` | quest names or numbers separated by spaces or commas, at most 200 characters: quests never shared; the host's value counts | empty |
| `shared_world` | `on` or `off`: the [shared world](../world/objects.md), experimental; doors, levers, lifts and shortcuts one player works change in the other's game too; a member's camp rest resets that area in the game of each other member there ([Camp rests in a shared area](playing-with-a-friend.md#camp-rests-in-a-shared-area)); each player's own. Both need it on | `on` |
| `shared_story` | `on` or `off`: [story together](../story/together.md), experimental; a cutscene or a talk the host plays plays in the guest's game too, with his choices, QTE results and skips; each player's own; both need it on | `on` |
| `hide_popups` | `on` or `off`: the game's Tutorial and Record popups (its own Settings rows) are Off while at least one other player is linked with you. Only a value that was On is turned off. Your values come back when the last player leaves, when you set it off or at `coop off`. The game's settings file keeps your values the whole time. Turn one on in the game's Settings during online play and it stays on until you leave. Each player's own. Options, Session, Hide popups online; it applies at once | `on` |
| `revive` | `on` or `off`: your friend may [revive](playing-with-a-friend.md#revive-by-your-friend-experimental) your EVE where she fell, experimental; `follow_key` on the death screen takes you [back to a living friend](playing-with-a-friend.md#back-to-a-friend-after-a-death); in a co-op Night Operation run, your death is a [down](../online/modes/nightop.md#down-and-revive) | `on` |
| `spectate` | `on` or `off`: down in a shared boss fight, you [watch a living friend](../fight/enemies.md#down-in-a-boss-fight-spectate) and get up when the boss falls, changes phase or reaches an HP scene; each player's own. Options, Session, Watch a friend when I fall; it applies at once | `on` |
| `photo_sync` | `both`, `notice` or `off`: the [synced photo mode](playing-with-a-friend.md#synced-photo-mode); a pause needs `both` on both PCs | `both` |
| `photo_freeze_max` | `0` (no limit) or `30` to `3600`: the longest pause your friend's photo mode holds your game in, in seconds | `600` |
| `photo_ghost` | `on` or `off`: your friend's ghost in your own photos | `on` |
| `photo_name_tag` | `on` or `off`: its name tag in your own photos | `on` |
| `photo_pause` | `full` or `scenery`: how your own photo mode [pauses your game](playing-with-a-friend.md#photo-mode-pause-experimental), experimental, from your next photo mode | `full` |
| `cutscene_wait` | `on` or `off`: as the guest, your game [waits](playing-with-a-friend.md#cutscene-wait) while a cutscene plays in the host's game | `on` |
| `follow_host` | `ask`, `always` or `off`: as the guest, the offer to [travel to the host](playing-with-a-friend.md#following-the-host); `always` starts the travel or the way back after a death by itself 5 s after its notice; `off` shows neither offer | `ask` |
| `collide` | `on` or `off`: the [solid partner](../online/partner.md#solid-partner-experimental), experimental. Also moves the enemies your game runs out of the ghost when the game's weight rule would move them out of your EVE (never in an SBO session) | `on` |
| `ui_scale` | `75` to `150`: the size of the menu, the chat and the partner HUD, in percent | `100` |
| `ui_sounds` | `on` or `off`: the game's UI sounds in the menu, the chat and the partner HUD | `on` |
| `ui_language` | `game` (the game's text language) or `english` | `game` |
| `chat` | `on` or `off`: the [session chat](interface.md#session-chat); off hides your friend's lines and sends none | `on` |
| `mod_names` | `on` or `off`: the names of your `.pak` mods go to your friend, for the [notice](../fight/enemies.md#shared-enemies-experimental) of the mods one of you lacks; off sends their count and hash only, and no path from a mod's own folder goes in your capture (see [Mods and CNS outfits](../online/partner.md#mods-and-cns-outfits)); no menu row | `on` |
| `partner_bar` | `on` or `off`: the [marker](interface.md#partner-hud) over your friend's ghost; on, it carries their name instead of the name tag | `on` |
| `partner_arrow` | `on` or `off`: the arrow toward your friend when they are out of view | `on` |
| `partner_card` | `on` or `off`: your friend's card at the top left | `on` |
| `card_details` | `on` or `off`: the ping and your friend's map on the card | `on` |
| `status_overlay` | `off`, `compact` or `detailed`: the [status strip](interface.md#status-strip-above-the-card) above the card | `compact` |
| `daynight` | `on` or `off`: the [day and night cycle](../world/daynight-internals.md). On, the sun moves on the open maps and SBO's own maps by one clock that every player shares: one real hour is one game day and the night runs from about :52 to :12 past each hour (UTC). Off gives each map Stellar Blade's own fixed light, as before. The Terrace hall stays a night hall either way. Options, Display, Day and night; it applies at once | `on` |
| `shortcut_load` | `on` or `off`: lets `coop shortcut load` write a [cut developer save](../cutmenus/menus.md#loading-one-coop-shortcut-load) as co-op slot 5; it can unlock Steam achievements; no menu row | `on` |
| `pvp_spike` | `on` or `off`: lets `coop pvp on` start the [PvP test](../online/lobby.md#the-pvp-test) with your friend: a stand-in enemy at their ghost takes your hits for their game, down to 1 HP; needs `shared_enemies=off`; no menu row | `on` |
| `sbo_lobby` | `on` or `off`: the [SBO lobby](../online/lobby.md), a test. On, the recruiter's Join saves the co-op game and takes you to the lobby in Xion's training room (a hall lobby with the hall lobby pak), and each co-op save is copied before the game rewrites it (10 copies kept per slot). At each arrival in the lobby the screen stays black until the lobby menu is ready, 8 s at most, then fades onto the open menu. No menu row | `on` |
| `scoreattack` | `on` or `off`: [score attack](../online/modes/scoreattack.md), a match mode of the SBO lobby. On, you play each round of a score attack lobby you are in. Off locks the lobby menu's Score attack row. You then sit out its rounds, with a notice. Options, Modes, Score attack; read at each round's start | `on` |
| `fishing` | `on` or `off`: the [fishing tournament](../online/modes/fishing.md), a mode of online sessions. On, you fish in each tournament the host of your online session starts with `coop fish start`. Off refuses your own start as the host. A guest with it off sits out each tournament, with a notice. Options, Modes, Fishing tournament; read at each start | `on` |
| `race_match` | `on` or `off`: [Doro races in matches](../online/modes/race.md#races-in-a-match) of the SBO lobby. On, you race each round of a race lobby you are in. Off locks the lobby menu's Doro race row. You then sit out its rounds, with a notice. Options, Modes, Doro race; read at each round's start. Doro races in an online session do not read it | `on` |
| `photohunt` | `on` or `off`: the [photo hunt](../online/modes/photohunt.md), a mode of online sessions. On, you photograph the targets of each photo hunt the host of your online session starts with `coop photohunt start`. Off refuses your own start as the host. A guest with it off sits out each round, with a notice. Options, Modes, Photo hunt; read at each start | `on` |

Rules:

- `F10` is refused because it opens the console (as does `~`). Function keys do not depend on the keyboard layout.
- Names and values ignore case, a UTF-8 BOM (Notepad) is accepted, and lines starting with `#` are comments.
- A refused value keeps its default, and `UE4SS.log` gives the reason in a `[StellarCoop] settings:` line. An unknown
  setting is ignored with a note.
- If two actions share one key, all the keys go back to their defaults: `F5` for the menu, `none` to host, `F6`, `F7`,
  `F8`, `F9`, `F3` and `F4`.
- A file written before `follow_key` existed that already holds `F7` for another action keeps it there: `follow_key`
  then reads `none`, with no log line.
- A file with no `race_key` line (one written before Doro races) whose other keys already use `F9`: `race_key` reads
  `none`, and `UE4SS.log` says so, for example `[StellarCoop] settings: F9 is leave_key: race_key has no key`.
  `coop race cp` still sets checkpoints.
- A file with no `bike_key` line (one written before the bike) whose other keys already use `F3`: `bike_key` reads
  `none` the same way, for example `[StellarCoop] settings: F3 is status_key: bike_key has no key`. `coop bike` still
  works.
- A file with no `gun_key` line whose other keys already use `F4`: `gun_key` reads `none` the same way, for example
  `[StellarCoop] settings: F4 is leave_key: gun_key has no key`. `coop gun` and a tap of D-pad Right still work.
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
- A file written by 0.5.0-beta.1 to 0.10.0 has comments that say `spawn_filter`, `shared_quests`, `revive`, `collide`
  and, from 0.7.0-beta.1, `shortcut_load` are off (a PvP test build adds `pvp_spike`). The mod sets each of them that
  says `off` to `on` and writes the new comment once. `photo_name_tag` and `status_overlay` go with the `shared_quests`
  comment, which the same versions wrote: `on` and `compact`. The old ghost comment, which said `dyes` and `effects`
  are off unless set, is replaced too. The mod keeps the file as it was as `coop-settings.old.txt` and logs a
  `[StellarCoop] settings:` line. An `off` set after that stays.
- A file written by 0.11.0 has a ghost comment that does not name `drone`, `sounds` and `faces`. The mod writes the new
  comment once, keeps the file as it was as `coop-settings.old.txt` and logs `[StellarCoop] settings: the comments in
  coop-settings.txt now read as this version writes them; no setting changed`.
- The `[StellarCoop] keys:` line gives the keys in use, the name tag and the send rate, for example
  `keys: menu=F5 host=none status=F6 leave=F8 race=F9, name tag on, 60 poses a second`. Another line says when a mod
  loaded earlier binds the same key; both actions then run. The `[StellarCoop] photo sync:` line gives the photo
  settings in use.

## Files in the mod folder

Everything the mod writes stays in `Mods/StellarCoop/`, apart from the save folder files listed in
[saves.md](saves.md#what-the-mod-reads-and-writes). An install never removes these files, and
`tools/install.py --uninstall` backs them up before it removes the folder.

| File | Written by | What it is |
| --- | --- | --- |
| `coop-settings.txt` | Lua, once, then the co-op menu | Your settings (see above) |
| `coop-settings.old.txt` | Lua, at the menu's first change since the mod loaded | `coop-settings.txt` as it was before that change |
| `coop-guide.txt` | Lua, on the guide's Don't show again or a close on its last page | One line. While it exists, the [guide](interface.md#guide) does not open by itself |
| `coop-records.txt` | Lua, after a challenge or Night Operation success that beats the best kept or a Doro race finish in a match that beats your best time on its track | Your best runs, one `best_<name>=<score> <seconds>` line each (see [online/modes/challenges.md](../online/modes/challenges.md#best-runs-coop-recordstxt)). Your best race times, one `best_race_<sum>=<ms> <track>` line each (see [Best times](../online/modes/race.md#best-times)). Written to `coop-records.txt.tmp` first, then renamed |
| `coop-blocked.txt` | native, after `coop remove`, `coop block` or `coop unblock` | Your [block list](playing-with-a-friend.md#block-list): two comment lines, then a salted hash of each blocked SteamID, one a line |
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
| `coop-spectate.txt` | Lua | The [spectate](../fight/enemies.md#down-in-a-boss-fight-spectate) camera's object path, so the next Lua load (Ctrl+R) can give the view back to your EVE and remove it |
| `coop-death-screen.txt` | Lua | One number while the friend's revive hides the game's death screen: its visibility from before, so the next Lua load (Ctrl+R) can show it again. Removed when the screen is shown again, or when the next Lua load finds it not hidden |
| `coop-quests.log` | native | The shared quests' steps made, held and refused, snapshots and stats lines, capped at 4 MB |
| `coop-quests.old.log` | native | The previous run's `coop-quests.log` |
| `coop-quests-record.txt` | native | The last shared quests recording (`coop quests record`) |
| `coop-request.txt` | Lua | A console request for the native part |
| `coop-session.txt` | Lua | A token per Lua load |
| `coop-components.txt` | Lua | Your EVE's capture (the component table) |
| `coop-remote.txt` | native | The remote table the ghost is built from. In a match lobby or an online session of more than 2 players, `coop-remote-<k>.txt` holds the table of the member in ghost slot k, 1 to 6 |
| `coop-cns.txt` | native, at start | The assets your CNS packs declare, one `<path> <outfit>` line each (empty without CNS packs): with `coop-shared-assets.txt`, the only paths from a mod's folder the ghost loads |
| `coop-cns-call.txt` | Lua | The crash sentinel's marker: `<path> <outfit>` while the ghost hands the engine an asset your CNS packs declare or a mod you both have holds (the container name in place of the outfit), empty otherwise. Written in place, with no `.tmp` file (see [When a mod asset fails](../online/partner.md#when-a-mod-asset-fails)) |
| `coop-shared-assets.txt` | native, when the list changes | The assets of the mods you and your friend both have in one version, one `<path> <container>` line each: loaded by the ghost as CNS paths are (see [Mods you both have](../online/partner.md#mods-you-both-have)) |
| `coop-cns-aside.txt` | Lua | The mod assets set aside after a crash: `version <mod version>`, then one `<path> <outfit>` line each. Cleared by `coop cns reset` and by another mod version |
| `coop-display.txt` | Lua | The ghost Lua built for that table |
| `coop-state.txt` | Lua | Whether a save is loaded or the title screen is shown, the send rate, your photo mode and the photo settings |
| `coop-puppet.txt` | Lua | The ghost's object path, so the next Lua load can remove a ghost left standing |
| `coop-ui.txt` | Lua | The co-op UI's on-screen root, so the next Lua load (Ctrl+R) can remove it and, if the menu was open, give the game its keys back |
| `coop-say.txt` | Lua | A chat line you typed, for a moment: the native part takes and deletes it at its next pass |
| `coop-chat.txt` | native | Your friend's chat, race and gift lines and the camp rests of the other players, for a moment: Lua takes and deletes the file within 250 ms, or within a frame while a race is armed |
| `StellarCoopStory.txt` | Lua, on `coop story` | The [story dump](../dev/story-dump.md#the-file), replaced at each run |
| `coop-story.txt` | you | A [story dump request](../dev/story-dump.md#the-request-file-coop-storytxt): the mod removes it and runs the dump once a world is loaded |
| `coop-night.txt` | Lua | Your side of a Night Operation run, for a moment: the native part takes and deletes it at its next pass and sends it to your friend |
| `coop-night-<steamid>-<index>.txt` | Lua | Your Night Operation shop points on that co-op slot, one line (see [online/modes/nightop-shop.md](../online/modes/nightop-shop.md)) |
| `coop-gift-<steamid>-<index>.txt` | Lua | Your mailbox on that co-op slot: the gifts that wait, the ones you sent that wait for an answer or come back, and the last 64 gifts taken (see [Cut mailbox](../cutmenus/menus.md#cut-mailbox-coop-gift)) |
| `coop-gift-toast.txt` | Lua | While a gift's toast shows: its object path, so the next Lua load (Ctrl+R) can take it off |
| `coop-race.txt` | Lua | Your [Doro race](../online/modes/race.md) lines, for a moment: the native part takes and deletes the file at its next pass |
| `coop-track-<name>.txt` | Lua, on `coop race save` | A Doro race track |
| `coop-tracks.txt` | Lua, on `coop race save` and `coop race match pick <name>` | The names of your tracks that a [match lobby](../online/modes/race.md#tracks-a-room-offers) may offer, one a line, the newest 32 |
| `coop-look.txt` | Lua | While the Doro look is on: EVE's object path, a dash (older versions wrote her main mesh's animation option there; the native part now keeps it and puts it back at a new Lua load), the Doro's object path, the names of the parts the look hid and, once the look hid the drone's body, the drone's object path, so the next Lua load (Ctrl+R) can show both again |
| `coop-race-doros.txt` | Lua | While a race shows Doros: their object paths, so the next Lua load (Ctrl+R) can remove them |
| `coop-drive.txt` | Lua | While the [bike](../vehicles/bike.md) drives EVE: her object path and her movement's four values from before, so the next Lua load (Ctrl+R) can put them back |
| `coop-bike.txt` | Lua | While EVE rides the [bike](../vehicles/bike.md): her object path and her main mesh's relative rotation and location from before, then on a `bike_pose=rig` ride the hidden copy's actor path and the mesh it wears, so the next Lua load (Ctrl+R) can free her body from the copy, remove the copy, put her mesh back and hide the bike |
| `coop-bike-<steamid>-<saves><index>.txt` | Lua, each time the bike is parked at a new place, never in the SBO lobby | Where your [bike](../vehicles/bike.md#where-the-bike-stays) stands for that Steam account and save, one line: version 1, the map, its position and its rotation (see [The place per save](../vehicles/bike-internals.md#the-place-per-save)) |
| `coop-bike-stand.txt` | Lua | While your parked bike stands in the world: its actor path, so the next Lua load (Ctrl+R) can remove it |
| `coop-bike-copies.txt` | Lua | While the other players' parked bikes show: their actor paths, tab-separated, so the next Lua load (Ctrl+R) can remove them |
| `coop-xion-rooms.txt` | Lua | While the rooms of [SBO Xion](../world/maps/sboxion.md#the-rooms) are open: the pieces of Stellar Blade hidden in their doorways with the values read before, on one line, so the next Lua load (Ctrl+R) can put them back |
| `coop-parked.txt` | Lua | Your parked bike's line (`park <map> <x> <y> <z> <pitch> <yaw> <roll>` or `none`), for a moment: the native part takes and deletes it at its next pass and sends it to the players linked with you |
| `coop-keep.txt` | Lua | The object paths of the assets the mod keeps in memory, one a line, the whole list each time it grows, for a moment: the native part takes and deletes it at its next pass |
| `coop-sbo.txt` | Lua | The object path of the SBO lobby's last menu camera, so the next Lua load (Ctrl+R) can remove it if it still stands |
| `coop-leviathan.txt` | Lua | While `coop leviathan show`, `coop gardener show` or `coop tendril show` shows a mesh or the free camera is on: the mesh actor's object path and the mesh's, the camera actor's path, the player controller's path, whether its move and look input were ignored before and the path of its view target before, so the next Lua load (Ctrl+R) can remove both and give the controller back |
| `coop-devmenu.txt` | Lua | After a `coop devmenu` row reached the game, until `coop off`: one line, so `coop off` runs `clear` and `lockswitch` even after a Lua reload (Ctrl+R) |
| `coop-bench.txt` | Lua, from the first `coop bench ghosts` on | The [ghost bench](../online/partner-internals.md#the-benchs-files)'s ghosts for the native part, or `bench off` once the bench ended. Kept after that |
| `coop-bench-table.txt` | native, while the ghost bench runs | EVE's capture table, which the bench ghosts are built on. Deleted when the bench ends. A crash can leave it until the next bench run ends |
| `coop-bench-out.txt` | native, once a second while the ghost bench runs | The bench's last second: frame times, the native tick's own time, the ghost writes and every 10 s the memory. Deleted when the bench ends. A crash can leave it until the next bench run ends |
| `coop-bench-ghosts.txt` | Lua, while the ghost bench runs | The bench ghosts' object paths, one a line, so the next Lua load (Ctrl+R) can remove them. That load empties it |
| `coop-gun.txt` | Lua | While [gun mode](../fight/gunmode.md) has changed the game: the table fields with their values from before; the masked keys; her body meshes under the rifle layer with their own post-process class; whether the rifle is out; her mesh's rotation and her movement's facing flags from before the aim; the hidden drone parts with their visibility from before; the aim camera's modifier; the morph's cube; the HUD entry and the crosshair in SB's HUD. The next Lua load (Ctrl+R) puts them back and removes the rifle, the cube, the modifier and the entry |
| `coop-wear.txt` | Lua | While `coop wear` puts a look on: your EVE's object path and, for her hair and her suit, the worn mesh's path and her own look (the mesh's path, the hair's animation Blueprint class, the hair's physics asset and the materials the game set on its slots), so the next Lua load (Ctrl+R) can give it back |

Each file shared between Lua and the native part is written in full to a `.tmp` file beside it and then renamed over it,
so neither side reads a half-written file. When the native part starts, it deletes the capture, remote, display, state,
chat, night and parked bike line files, `coop-race.txt` and any stale request or report. Then it writes `coop-cns.txt`
again. The chat files and `coop-race.txt` are also deleted when a session ends and when the game exits. A run without
`coop no` writes no probe file, so `nightop-probe.old.txt` can be older than the previous run.

An install and the release zip both add `Scripts/version.lua`. An install also writes `install-manifest.txt`; the
release zip adds `INSTALL.md`, `CHANGELOG.md` and `SHA256SUMS.txt`.
