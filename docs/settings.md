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
# Shortcut saves, a test tool: on or off, off by default. On, coop shortcut load <map> <1-4> writes one of the game's
# cut developer saves as your co-op slot 5 (StellarBladeCoop04.sav, backed up first), without its achievement list.
# A Steam achievement it still unlocks cannot be taken back: use it only on a Steam account whose achievements do not
# matter (docs/usage.md, Cut Load Shortcut saves).
shortcut_load=off
```

| Setting | Values | Default |
| --- | --- | --- |
| `menu_key` | `F1` to `F12` except `F10`, with at most one of `Shift+`, `Ctrl+` or `Alt+` in front | `F5` |
| `host_key` | same, or `none`: a key that hosts at once, without the menu | `none` |
| `status_key` | same as `menu_key` | `F6` |
| `leave_key` | same as `menu_key` | `F8` |
| `follow_key` | same as `menu_key`, or `none`: as the guest, travel to the host ([Following the host](playing-with-a-friend.md#following-the-host)) | `F7` |
| `race_key` | same, or `none`: a key that sets a [Doro race](doro-races.md) checkpoint while you record a track | `F9` |
| `drift_keys` | up to 4 Unreal key names separated by spaces, or `none`: the keys held to [drift](doro-races.md#driving) in a race | `Gamepad_RightTrigger B` |
| `who_can_join` | `friends`, `code` or `private`: who can join a session you host (`code`: anyone with your [join code](playing-with-a-friend.md#join-codes); `private`: only the friends you invite) | `friends` |
| `auto_coop_save` | `ask`, `always` or `off`: the [co-op saves](playing-with-a-friend.md#co-op-saves) at the title | `ask` |
| `name_tag` | `on` or `off`: your friend's Steam name above their ghost | `on` |
| `send_rate` | `10` to `60` poses sent a second at most (a link that cannot keep up lowers it to 30 or 20 for a while: [link health](internals/steam-link.md#link-health-in-the-log)) | `60` |
| `cloth` | `on` or `off`: her ponytail as cloth on the ghost you see | `on` |
| `dyes` | `on` or `off` | `off` |
| `effects` | `on` or `off` | `off` |
| `shared_enemies` | `on` or `off`: [shared enemies](shared-enemies.md#shared-enemies-experimental), experimental | `on` |
| `fight_chars` | `auto` (every common enemy), or at most 16 enemy character ids, whole numbers separated by spaces | `auto` |
| `guest_kills` | `at_once` or `confirmed`: as the guest, whether an enemy your hit kills dies at once on your screen or waits for the host's game (see [shared enemies](shared-enemies.md#shared-enemies-experimental)) | `at_once` |
| `enemy_hp_scale` | `1.0` to `4.0`: the host's multiplier for a shared enemy's maximum HP, used in both games | `1.35` |
| `enemy_balance_scale` | `1.0` to `4.0`: the host's multiplier for a shared enemy's balance gauge, used in both games | `1.15` |
| `kill_credit` | `together` or `fought`: when a shared enemy dies in your game, with its rewards and achievements: you hit it, it targeted you, or (`together` only) you stood within 30 m when it died (see [shared enemies](shared-enemies.md#shared-enemies-experimental)) | `together` |
| `same_place` | `on` or `off`: [same place](shared-enemies.md#same-place-experimental), experimental; the host's value counts for both games | `on` |
| `aggro` | `game` or `host`: with same place, whether each enemy fights the player who hit it last (or else the nearer one) or the host only; the host's value counts for both games | `game` |
| `same_spawns` | `on` or `off`: [same spawns](shared-enemies.md#same-spawns-experimental), experimental; the host's value counts for both games | `on` |
| `enemy_extra` | `0` to `3`: [extra enemies](shared-enemies.md#extra-enemies-experimental) for each common enemy, experimental, with same spawns only; the host's value counts for both games | `0` |
| `spawn_filter` | `on` or `off`: the [spawn filter](shared-enemies.md#spawn-filter-experimental), experimental; your own, used when you are the guest; no menu row | `off` |
| `bosses` | `on` or `off`: [shared bosses](shared-enemies.md#shared-bosses-experimental), experimental; the host's value counts for both games | `on` |
| `boss_hp_scale` | `1.0` to `4.0`: the host's multiplier for a shared boss's maximum HP, used in both games | `2.0` |
| `shared_quests` | `on` or `off`: [shared quests](playing-with-a-friend.md#shared-quests-experimental), experimental; both players need it on | `off` |
| `quest_deny` | quest names or numbers separated by spaces or commas, at most 200 characters: quests never shared; the host's value counts | empty |
| `revive` | `on` or `off`: your friend may [revive](playing-with-a-friend.md#revive-by-your-friend-experimental) your EVE where she fell, experimental; in a co-op Night Operation run, your death is a [down](night-operation.md#down-and-revive) | `off` |
| `photo_sync` | `both`, `notice` or `off`: the [synced photo mode](playing-with-a-friend.md#synced-photo-mode); a pause needs `both` on both PCs | `both` |
| `photo_freeze_max` | `0` (no limit) or `30` to `3600`: the longest pause your friend's photo mode holds your game in, in seconds | `600` |
| `photo_ghost` | `on` or `off`: your friend's ghost in your own photos | `on` |
| `photo_name_tag` | `on` or `off`: its name tag in your own photos | `off` |
| `cutscene_wait` | `on` or `off`: as the guest, your game [waits](playing-with-a-friend.md#cutscene-wait) while a cutscene plays in the host's game | `on` |
| `follow_host` | `ask`, `always` or `off`: as the guest, the offer to [travel to the host](playing-with-a-friend.md#following-the-host) | `ask` |
| `collide` | `on` or `off`: the [solid partner](ghost.md#solid-partner-experimental), experimental | `off` |
| `ui_scale` | `75` to `150`: the size of the menu, the chat and the partner HUD, in percent | `100` |
| `ui_sounds` | `on` or `off`: the game's UI sounds in the menu, the chat and the partner HUD | `on` |
| `ui_language` | `game` (the game's text language) or `english` | `game` |
| `chat` | `on` or `off`: the [session chat](interface.md#session-chat); off hides your friend's lines and sends none | `on` |
| `mod_names` | `on` or `off`: the names of your `.pak` mods go to your friend, for the [notice](shared-enemies.md#shared-enemies-experimental) of the mods one of you lacks; off sends their count and hash only, and no path from a mod's own folder goes in your capture (see [Mods and CNS outfits](ghost.md#mods-and-cns-outfits)); no menu row | `on` |
| `partner_bar` | `on` or `off`: the [marker](interface.md#partner-hud) over your friend's ghost; on, it carries their name instead of the name tag | `on` |
| `partner_arrow` | `on` or `off`: the arrow toward your friend when they are out of view | `on` |
| `partner_card` | `on` or `off`: your friend's card at the top left | `on` |
| `card_details` | `on` or `off`: the ping and your friend's map on the card | `on` |
| `status_overlay` | `off`, `compact` or `detailed`: the [status strip](interface.md#status-strip-above-the-card) above the card | `off` |
| `shortcut_load` | `on` or `off`: lets `coop shortcut load` write a [cut developer save](cut-scenes-and-menus.md#loading-one-coop-shortcut-load) as co-op slot 5; it can unlock Steam achievements; no menu row | `off` |

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

## Files in the mod folder

Everything the mod writes stays in `Mods/StellarCoop/`, apart from the save folder files listed in
[saves.md](saves.md#what-the-mod-reads-and-writes). An install never removes these files, and
`tools/install.py --uninstall` backs them up before it removes the folder.

| File | Written by | What it is |
| --- | --- | --- |
| `coop-settings.txt` | Lua, once, then the co-op menu | Your settings (see above) |
| `coop-settings.old.txt` | Lua, at the menu's first change since the mod loaded | `coop-settings.txt` as it was before that change |
| `coop-guide.txt` | Lua, on the guide's Don't show again or a close on its last page | One line. While it exists, the [guide](interface.md#guide) does not open by itself |
| `coop-records.txt` | Lua, after a challenge or Night Operation success that beats the best kept | Your best runs, one `best_<name>=<score> <seconds>` line each (see [challenges.md](challenges.md#best-runs-coop-recordstxt)). Written to `coop-records.txt.tmp` first, then renamed |
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
| `coop-cns.txt` | native, at start | The assets your CNS packs declare, one `<path> <outfit>` line each (empty without CNS packs): with `coop-shared-assets.txt`, the only paths from a mod's folder the ghost loads |
| `coop-cns-call.txt` | Lua | The crash sentinel's marker: `<path> <outfit>` while the ghost hands the engine an asset your CNS packs declare or a mod you both have holds (the container name in place of the outfit), empty otherwise. Written in place, with no `.tmp` file (see [When a mod asset fails](ghost.md#when-a-mod-asset-fails)) |
| `coop-shared-assets.txt` | native, when the list changes | The assets of the mods you and your friend both have in one version, one `<path> <container>` line each: loaded by the ghost as CNS paths are (see [Mods you both have](ghost.md#mods-you-both-have)) |
| `coop-cns-aside.txt` | Lua | The mod assets set aside after a crash: `version <mod version>`, then one `<path> <outfit>` line each. Cleared by `coop cns reset` and by another mod version |
| `coop-display.txt` | Lua | The ghost Lua built for that table |
| `coop-state.txt` | Lua | Whether a save is loaded or the title screen is shown, the send rate, your photo mode and the photo settings |
| `coop-puppet.txt` | Lua | The ghost's object path, so the next Lua load can remove a ghost left standing |
| `coop-ui.txt` | Lua | The co-op UI's on-screen root, so the next Lua load (Ctrl+R) can remove it and, if the menu was open, give the game its keys back |
| `coop-say.txt` | Lua | A chat line you typed, for a moment: the native part takes and deletes it at its next pass |
| `coop-chat.txt` | native | Your friend's chat lines and race lines, for a moment: Lua takes and deletes the file within 250 ms, or within a frame while a race is armed |
| `coop-night.txt` | Lua | Your side of a Night Operation run, for a moment: the native part takes and deletes it at its next pass and sends it to your friend |
| `coop-night-<steamid>-<index>.txt` | Lua | Your Night Operation shop points on that co-op slot, one line (see [night-operation-shop.md](night-operation-shop.md)) |
| `coop-gift-<steamid>-<index>.txt` | Lua | Your mailbox on that co-op slot: the gifts that wait, the ones you sent that wait for an answer or come back, and the last 64 gifts taken (see [Cut mailbox](cut-scenes-and-menus.md#cut-mailbox-coop-gift)) |
| `coop-gift-toast.txt` | Lua | While a gift's toast shows: its object path, so the next Lua load (Ctrl+R) can take it off |
| `coop-race.txt` | Lua | Your [Doro race](doro-races.md) lines, for a moment: the native part takes and deletes the file at its next pass |
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
