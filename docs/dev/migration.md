# Moving a fork to the November 2026 layout

Between `38bd9dfe` and `8da078ab` the code moved into one folder per module with no links between modules.
`main.lua`, `ui/text.lua` and `native/src/link/core.h` were split into smaller files. Behaviour did not change, except
that a module that fails to load is now off alone and one message of the save check names `docs/players/saves.md`.

## Merging

`git merge` detects renames, so an edit to a moved file usually lands at its new path. An edit to `main.lua`, a file of
`commands/`, `ui/text.lua` or `link/core.h` does not: re-apply it in the file the tables below name. Then run
`python3 tools/install.py --dry-run`, which checks and builds without installing.

Git misses three moves. `docs/how-it-works.md` is now `docs/internals/README.md`, with most of its lines changed by the
new links. `native/src/glue/tick/world_game.inc` is now `native/src/world/world_game.inc`: git pairs it with
`native/src/glue/tick/world_game_shared.inc`, which took 16 of its items. `tests/lua/cut/enemy_test.lua` is now
`tests/lua/core/enemy_test.lua`: git pairs it with the cut enemies' copy, `tests/lua/cut/enemies/enemy_test.lua`,
because core's test gained a scan of its own source.

## Modules

Lua folders are under `mod/StellarCoop/Scripts/`, native folders under `native/src/`. The console words are typed as
`coop <word>`. `ui` and `off` stay in the runtime (`main/commands.lua`); `guide` and `keys` are in
`ui/kit/commands.lua`.

| Module | Lua | Native | Console words |
| --- | --- | --- | --- |
| `partner` | `partner/` | `pose/` | `puppet`, `loopback`, `record`, `replay`, `basesuit`, `where`, `near`, `cns`, `look` |
| `nightop` | `nightop/` | `nightop/` | `no`, `nightop`, `challenge`, `recruiter` |
| `cut.enemies` | `cut/enemies/` | none (its rows are in `lion/`) | `leviathan` and the viewer's other words, `gardener`, `tendril`, `lion` |
| `group` | `group/` | `group/` | `revive`, `travel` |
| `race` | `race/` | none | `race` |
| `cut.eve` | `cut/eve/` | `cut/` (`debug_keys.h`, the anim and debug parts) | `wear`, `emote`, `fly`, `slowmo`, `glide`, `chainspin` |
| `cut.scenes` | `cut/scenes/` | none | `scene`, `lines` |
| `matrix13` | `matrix13/` | `matrix13/` | `mxiii`, `lily` |
| `session` | `session/` | `session/` | `host`, `invite`, `leave`, `report`, `copy`, `mark`, `allow`, `deny`, `remove`, `mute`, `unmute`, `block`, `unblock`, `blocked`, `join`, `list`, `status` |
| `photo` | `photo/` | `photo/` | `freeze` |
| `fight` | `fight/` | `fight/` | `fight`, `pvp` |
| `quest` | `quest/` | `quest/` | `quests` |
| `world` | `world/` | `world/` | `world` |
| `story` | `story/` | `story/` | `scenes`, `story` |
| `lobby` | `lobby/` | `lobby/` | `match`, `sbo` |
| `bike` | `bike/` | `bike/` | `bike` |
| `sky` | `sky/` | `sky/` | `daynight` |
| `cut.menus` | `cut/menus/` | `cut/` (`items.h` and its part) | `gift`, `devmenu`, `devinfo` |
| `save` | `save/` | `save/` | `saves`, `shortcut` |

## Lua module names

Each `require` name that changed:

| Before | After |
| --- | --- |
| `cut.chainspin` | `cut.eve.chainspin` |
| `cut.devmenu` | `cut.menus.devmenu` |
| `cut.emote` | `cut.eve.emote` |
| `cut.enemy` | `core.enemy` |
| `cut.flight` | `cut.eve.flight` |
| `cut.gardener` | `cut.enemies.gardener` |
| `cut.glide` | `cut.eve.glide` |
| `cut.leviathan` | `cut.enemies.leviathan` |
| `cut.lines` | `cut.scenes.lines` |
| `cut.lion_rows` | `core.lion_rows` |
| `cut.lion` | `cut.enemies.lion` |
| `cut.mailbox` | `cut.menus.mailbox` |
| `cut.scene` | `cut.scenes.scene` |
| `cut.tendril` | `cut.enemies.tendril` |
| `cut.wear` | `cut.eve.wear` |
| `session.arrival` | `lobby.arrival` |
| `session.group` | `group.group` |
| `session.halls_rows` | `lobby.halls_rows` |
| `session.saves` | `save.saves` |
| `session.sbo_maps` | `lobby.sbo_maps` |
| `session.sbo` | `lobby.sbo` |
| `session.travel` | `group.travel` |
| `story.subtitles` | `matrix13.quest.subtitles` |
| `ui.create_model` | `session.ui.create_model` |
| `ui.create` | `session.ui.create` |
| `ui.guide_text` | `ui.text.guide` |
| `ui.guide` | `ui.kit.guide` |
| `ui.kit` | `ui.kit.kit` |
| `ui.lobby_model` | `lobby.ui.lobby_model` |
| `ui.lobby` | `lobby.ui.lobby` |
| `ui.menu` | `ui.kit.menu` |
| `ui.model` | `ui.kit.model` |
| `ui.notice` | `ui.kit.notice` |
| `ui.parts` | `ui.kit.parts` |
| `ui.pause_tab` | `ui.kit.pause_tab` |
| `ui.region_tabs` | `group.region_tabs` |
| `ui.sessions_model` | `session.ui.sessions_model` |
| `ui.sessions` | `session.ui.sessions` |

These helpers were cut out of a module into a shared file. The old module keeps them under the old names through
alias lines; a caller in another module now requires the new file.

| Before | After |
| --- | --- |
| `session.chat`'s `clean`, `wrap`, `columns` | `core.line` |
| `session.join`'s `name`, `feed` | `core.line` |
| `session.travel`'s `number` | `core.line` |
| `session.travel`'s `WORLDS` | `core.worlds` (the table itself) |
| `partner.hud`'s `OFF`, `ON`, `camera_space`, `edge`, `place`, `distance`, `where`, `hp_columns`, `shield_block`, `cube` | `ui.kit.hud_parts` |
| `nightop.probe`'s `her`, `controller` | `core.player` |
| `matrix13.quest.zone_talks`'s `engaged` | `core.player` |
| `race.doro`'s `same`, `resolve`, `reloads`, `attach`, `detach`, `spawn`, `sweep`, `remove`, `apply`, `ASSETS` | `core.actors` |
| `matrix13.world.travel`'s `paks_of` | `core.pak_gate` |
| A puppet's `world()`, `me()` (`partner.puppet`) | `core.where` |
| `nightop.recruiter`'s `edit`, `one`, `find_name`, `index_of`, `ascii` | `core.row_edit` |
| `nightop.roxanne`'s `watcher` | `core.picks` |
| `nightop.shop`'s `add`, `guid`, `MOST` | `core.items` |
| `cut.chainspin`'s `apply`, `target` | `core.effect` |
| `nightop.recruiter_text`'s `culture` | `ui.text.culture` |

## Split files

Git does not follow an edit to these files: they were cut by hand. Paths are under `mod/StellarCoop/Scripts/`, or
`native/src/` for `link/`.

### main.lua

The old `main.lua` ran from top to bottom in 18 sections. Each section is now in the runtime (`main.lua`, `main/`) or
in a module's `wiring.lua`, which holds what the module builds, what it reads later of other modules and the fields of
`M` it sets. A local of the old file that another file reads is now a field of `M`.

| Section of the old main.lua | Runtime | Modules |
| --- | --- | --- |
| The command comment at the top | removed: `docs/usage.md` lists the keys and words | |
| Masked print and log, `VERSION` | `main.lua` | |
| Boot | `main.lua` keeps the mod folder; `main/boot.lua`: the DLL, the native tick and pad, the pause close, the link, the settings, `look` and `looks`, the session token | |
| Base | `main/base.lua`: `notice`, the UI's names, `open_screen`, `ui_reset`, `say`, `T`, `words`, `tell`, the UE4SS-settings.ini check, `native_off`, `off`, `blocked`, `USAGE`, `ask`, `slot_line`, `coop_slot` | partner: `capture`, `sentinel` and its note, `puppet`, `ghosts`, `ghost_of` |
| Modes | | nightop: `probe`, `night`, `Recruiter`, `recruiter`; cut.enemies: `lion`, `gardener`, `tendril`; matrix13: `mxiii`; group: `region_tabs` |
| Features | `main/base.lua`: `ui_log`, `riding()`, `game_words`, `chat_clock`; `main/pass.lua`: `alone_told`, `heard_by_member` | race: `doro`, `drive`, `race`; cut.enemies: `leviathan`; cut.eve: `wear`, `glide`, `emote`; cut.scenes: `scene`, `lines`; session: `chat`, `Join` |
| Photo | `main/base.lua`: `photo_failed`, `photo_state` | photo: `PAUSE_METHOD`, `pause`, `photo_pause`, the pause's lines of coop off as `photo_off()` |
| Sync | | fight, quest, world, story: their auto and wanted values, their kill switches |
| Lobby | | lobby: `arrival` and its hook, `halls`, `sbo` |
| Context | `main/base.lua`: `fname`, `logic_paused` | cut.eve: `flight`, `chainspin`; bike: `ride`, `fetch`, `others`; partner: `capture.leave_out`; sky: `daynight`; cut.menus: `devmenu`, `mailbox`; story: the dump |
| Commands | `main/commands.lua`: coop ui, coop off, `report`, `report_each`, `run`; `main/base.lua`: `OFF` | nightop: `roxanne`, `guard_text`; matrix13: `talks`, `mila`, `lily`; partner: the ghost's blocks of coop off as `ghosts_off()` |
| UI | `main/ui.lua`: the kit, the guide, the menu, the pause tab, with each module's build step at its old place | session: `booth`, `box`, `code_box`, `sessions`, `create`, `approval`; save: `saves_ui`; lobby: `lobby_room`, `lobby_menu`, `lobby_key`, `seat_hint`, its screens; partner, nightop, race, matrix13: their HUDs |
| Input | `main/input.lua` | |
| Frame loop | `main/frame.lua`: `guarded`, `peaked`, the loop | |
| Online notices | `main/pass.lua`: `last_mode`, `shared_seen`, the link's notices, the CNS log line; `main/base.lua`: `her_name` | group: `group`, `travel`; fight: the fight and pilot notices; quest, world, story: their notices; session: the paks, DLC and cycle notices; partner: the ghost's toggle when a session starts, as `ghost_start()` |
| 250 ms loop | `main/pass.lua`: the loop | lobby: `arrival_pass`, `lobby_pass`, `hud_pass`; fight, quest, world, story: their asks as `fight_asks()`, `quests_asks()`, `world_asks()`, `scenes_asks()` |
| Key binds | `main/keys.lua` | |
| The `Loaded version` line | `main.lua` | |

The tests of one module's wiring moved to that module's folder ([Every moved file](#every-moved-file) lists them).
`tests/lua/main/sbo_test.lua` is now `tests/lua/lobby/wiring_test.lua`, except its case of the ghost's collision in an
SBO session, which stayed with the runtime as `tests/lua/main/collide_test.lua`.

### Console commands

Each handler of `commands/<file>.lua` moved, with the comment lines above it, into the `commands.lua` of the module its
word drives. The words did not change.

| Before | Words | After |
| --- | --- | --- |
| `commands/bike.lua` | `bike` | `bike/commands.lua` |
| `commands/cut.lua` | `leviathan` and the viewer's other words, `gardener`, `tendril`, `lion` | `cut/enemies/commands.lua` |
| `commands/cut.lua` | `wear`, `emote`, `fly`, `slowmo`, `glide`, `chainspin` | `cut/eve/commands.lua` |
| `commands/cut.lua` | `scene`, `lines` | `cut/scenes/commands.lua` |
| `commands/cut.lua` | `gift`, `devmenu`, `devinfo` | `cut/menus/commands.lua` |
| `commands/cut.lua` | `mxiii` | `matrix13/commands.lua` |
| `commands/cut.lua` | `shortcut` | `save/commands.lua` |
| `commands/daynight.lua` | `daynight` | `sky/commands.lua` |
| `commands/fight.lua` | `fight`, `pvp` | `fight/commands.lua` |
| `commands/fight.lua` | `quests` | `quest/commands.lua` |
| `commands/guide.lua` | `guide` | `ui/kit/commands.lua` |
| `commands/keys.lua` | `keys` | `ui/kit/commands.lua` |
| `commands/nightop.lua` | `no`, `nightop`, `challenge`, `recruiter` | `nightop/commands.lua` |
| `commands/partner.lua` | `puppet`, `loopback`, `record`, `replay`, `basesuit`, `where`, `near`, `cns`, `look` | `partner/commands.lua` |
| `commands/partner.lua` | `freeze` | `photo/commands.lua` |
| `commands/race.lua` | `race` | `race/commands.lua` |
| `commands/scenes.lua` | `scenes` | `story/commands.lua` |
| `commands/session.lua` | `host`, `invite`, `leave`, `report`, `copy`, `mark`, `allow`, `deny`, `remove`, `mute`, `unmute`, `block`, `unblock`, `blocked`, `join`, `list`, `status` | `session/commands.lua` |
| `commands/session.lua` | `match`, `sbo` | `lobby/commands.lua` |
| `commands/session.lua` | `revive`, `travel` | `group/commands.lua` |
| `commands/session.lua` | `saves` | `save/commands.lua` |
| `commands/story.lua` | `story` | `story/commands.lua` |
| `commands/story.lua` | `lily` | `matrix13/commands.lua` |
| `commands/world.lua` | `world` | `world/commands.lua` |

In the tests, `tests/lua/commands/session_test.lua` is now `tests/lua/session/commands_test.lua`. Section 15 of
`tests/lua/bike/ride_test.lua` (`coop race look` refused while EVE rides) is now in `tests/lua/race/commands_test.lua`.

### ui/text.lua

`ui/text.lua` keeps its helpers and requires one file per language. Each `T.<culture>={...}` table moved whole to
`ui/text/<culture>.lua`, for the 22 cultures `ar`, `da`, `de`, `en`, `es`, `es-MX`, `fi`, `fr`, `it`, `ja`, `ko`, `nl`,
`no`, `pl`, `pt`, `pt-BR`, `ru`, `sv`, `th`, `tr`, `zh-Hans` and `zh-Hant`. Each language file also holds `modules`,
the modules' names that the notice of a module that failed to load says. The guide's table moved from
`ui/guide_text.lua` to `ui/text/guide.lua`; the guard's `culture()` is now in `ui/text/culture.lua`.

### link/core.h

`link/core.h` keeps the tuning constants, `Match`, `Round`, `splitmix64`, `block_hash`, `join_refusal` and the data
members of class `Link`. Its member functions moved, each with the comment above it, into `link/core/<concern>.inc`,
which the class includes in this order:

| File | Holds | First function | Last function |
| --- | --- | --- | --- |
| `link/core/tick.inc` | The constructor, Steam's start, whether a save is loaded, the worker's pass, the event line | `Link` | `event` |
| `link/core/members.inc` | The members and the pair: who is linked, the partner and the leader, ghost slots, the members pass | `member_update` | `send_let` |
| `link/core/match.inc` | Match lobbies: quick match, the search and its regroup, the host's countdown and rounds | `match` | `describe_tag` |
| `link/core/channels.inc` | Sends and receives on channels 0 to 2, their rate windows and the flood rule, channel 2's queues, the pings | `pose_rate` | `ping_peers` |
| `link/core/lines.inc` | The players' lines on channel 0: chat, race, gift, vitals, night, bike, photo mode, mods, DLCs, the New Game+ cycle | `paks` | `photo_pass` |
| `link/core/status.inc` | Notices, coop report, the copy request, the status file, the 60 s line | `notice` | `poll_relay` |
| `link/core/approvals.inc` | Who gets in: the block list, a private session, the host's no, her questions one at a time, session requests | `blocks` | `on_session_request` |
| `link/core/messages.inc` | Channel 0's dispatch: each line a member sends, by kind | `on_message` | `on_message` |
| `link/core/lobby.inc` | The lobby: its data, join, leave and rejoin, invites, relay only, its owner, Steam's call results | `data_word` | `poll_calls` |
| `link/core/list.inc` | The session list: the host's rows, the Public search, the friends' walk | `ask_list` | `refresh_rows` |
| `link/core/requests.inc` | Lua's requests: one switch over `Command` | `handle` | `handle` |

The blocks before the class went into four headers:

| File | Holds |
| --- | --- |
| `link/steam.h` | Steamworks 1.59's layouts and values the link reads, the SessionRequest's SteamID, the flat API table and its loader |
| `link/journal.h` | The link's numbered events, for the log and coop report |
| `link/pose_cap.h` | The adaptive pose rate: each member's cap |
| `link/peer.h` | A member as the link holds her, her rate windows, the callback counters |

## Copies

Feature code two modules used was copied into each of them with its tests. Each copy's first line after the license
says whose copy it is. Paths are under `mod/StellarCoop/Scripts/`.

| From | To | Its tests |
| --- | --- | --- |
| `race/drive.lua` | `bike/drive.lua` | `tests/lua/race/drive_test.lua` copied to `tests/lua/bike/drive_test.lua` |
| `race/drive_model.lua` | `bike/drive_model.lua` | `tests/lua/race/drive_model_test.lua` copied to `tests/lua/bike/drive_model_test.lua` |
| `race/doro.lua` from `local RUN,MAX_RATE` to `Doro.tilted`: the Doro look's clip choice and tilt | `partner/doro_pick.lua` | the `Doro.pick` and `Doro.tilted` cases of `tests/lua/race/doro_test.lua`, copied to `tests/lua/partner/doro_pick_test.lua` |
| `core/enemy.lua` (before: `cut/enemy.lua`), whole | `cut/enemies/enemy.lua` | `tests/lua/core/enemy_test.lua` copied to `tests/lua/cut/enemies/enemy_test.lua` |
| `bike/ride.lua`'s `find_part` with `Ride.MESH`, `Ride.TAG`, `SKINNED`, `path_of`, `her` | `partner/bike_part.lua` | new: `tests/lua/partner/bike_part_test.lua` |
| The Lion's and the Gardener's row batch expressions of `cut/enemies/lion.lua` and `cut/enemies/gardener.lua` | `matrix13/world/travel.lua`'s `BATCHES` | `tests/lua/matrix13/world/travel_test.lua` |
| `commands/session.lua`'s `join` | `lobby/commands.lua`'s local `join`, for `coop match join` | none |

Section 9 of `tests/lua/race/drive_test.lua`, which drove `bike/model.lua` through the race's drive, is now only in
the bike's copy, `tests/lua/bike/drive_test.lua`. The race's section 9 now checks that `coop race drive probe` and
`coop race drive off` are refused while EVE rides.

A fork's fix to `race/drive.lua`, `race/drive_model.lua` or the Doro pick goes to both copies when it concerns both. A
fix to `cut/enemy.lua` goes to `core/enemy.lua` when it concerns the row batches of the lobby or Matrix XIII, to
`cut/enemies/enemy.lua` when it concerns the cut enemies.

## Shared native parts

Paths are under `native/src/`. These headers moved to `game/` because another module reads them. Their tests moved to
the same place under `tests/native/game/`.

| Before | After |
| --- | --- |
| `fight/pilot.h` | `game/pilot.h` |
| `fight/pvp.h` | `game/pvp.h` |
| `fight/spawn_sync.h` | `game/spawn_sync.h` |
| `fight/sync.h` | `game/fight/sync.h` |
| `fight/types.h` | `game/types.h` |
| `pose/codec.h` | `game/codec.h` |
| `pose/core.h` | `game/core.h` |
| `pose/engine.h` | `game/pose/engine.h` |
| `pose/stream.h` | `game/stream.h` |
| `pose/table.h` | `game/table.h` |
| `quest/engine.h` | `game/quest/engine.h` |
| `quest/sync.h` | `game/quest/sync.h` |
| `save/rotation.h` | `game/rotation.h` |
| `save/sbo_record.h` | `game/sbo_record.h` |
| `save/shortcut.h` | `game/shortcut.h` |
| `save/shortcut_load.h` | `game/shortcut_load.h` |
| `save/slot.h` | `game/slot.h` |
| `save/twins.h` | `game/twins.h` |
| `story/engine.h` | `game/story/engine.h` |
| `story/rows.h` | `game/story/rows.h` |
| `story/sync.h` | `game/story/sync.h` |
| `world/engine.h` | `game/world/engine.h` |
| `world/rows.h` | `game/world/rows.h` |
| `world/sync.h` | `game/world/sync.h` |

Each part below lost the items that other modules' parts read: they moved, whole and in order, into
`glue/tick/<part>_shared.inc`, which `glue/tick.cpp` includes right before the part. An edit to one of these items goes
to the shared part.

| Part | Shared part | Items |
| --- | --- | --- |
| `pose/pose_game.inc` | `glue/tick/pose_game_shared.inc` | The game thread's base: `base`, `objects`, `engine_on`, the fault filter, the clock, the pad's reads (28 items) |
| `fight/fight_game.inc` | `glue/tick/fight_game_shared.inc` | `game_function`, `FindActor`, `ZoneRow`, `SpawnRow`, `fault_in_dll` and the game offsets they call |
| `photo/freeze_game.inc` | `glue/tick/freeze_game_shared.inc` | `MakeName`, `NameView`, `Controller`, `GetWorld`, `FreezeGame`, `PauseTag` with their offsets, `freeze_sync`, `freeze_held`, `freeze_faulted`, `freeze_name`, `story_scene` |
| `quest/quests_game.inc` | `glue/tick/quests_game_shared.inc` | `quest_engine` |
| `fight/pilot_game.inc` | `glue/tick/pilot_game_shared.inc` | `FindFsb`, `kFindFsb`, `kFindCharacter` |
| `group/camps_game.inc` | `glue/tick/camps_game_shared.inc` | `camps_name` |
| `cut/debug_game.inc` | `glue/tick/debug_game_shared.inc` | `FindUi`, `OpenUi`, `CloseUi`, `UiType`, `EmptyName`, `ui_reads` |
| `cut/anim_game.inc` | `glue/tick/anim_game_shared.inc` | `FStringArg`, `anim_live`, `anim_read` |
| `matrix13/camp_text_game.inc` | `glue/tick/camp_text_game_shared.inc` | `AssignString`, `DisplayString`, `SharedRef`, `SingletonGet`, `TextKey`, `TextKeyOut`, `DestroyObject`, `DestroyController`, `camp_text_view`, `camp_text_release`, `camp_text_count` |
| `save/shortcut_game.inc` | `glue/tick/shortcut_game_shared.inc` | `virtual_at` |
| `world/world_game.inc` | `glue/tick/world_game_shared.inc` | `world_global`, `world_game`, `world_engine`, `world_event_root`, the shared world's state and latch (16 items) |
| `story/story_game.inc` | `glue/tick/story_game_shared.inc` | The story trips' state and latch (14 items) |
| `lobby/sbo_game.inc` | `glue/tick/sbo_game_shared.inc` | `RunZoneEvent`, `JoinRun`, the Join hook and its state |
| `save/saves_worker.inc` | `glue/tick/saves_worker_shared.inc` | `loaded_slot`, `saves_now`, `reloading`, `names` |
| `fight/fight_worker.inc` | `glue/tick/fight_worker_shared.inc` | `fault_where`, `Filter`, `fight_gate`, `slot_value`, `swap_slot` |
| `lobby/sbo_worker.inc` | `glue/tick/sbo_worker_shared.inc` | `sbo_run`, `sbo_refusal`, `join_slot_install`, the hook's slot |
| `quest/quests_worker.inc` | `glue/tick/quests_worker_shared.inc` | `quest_slot_line` |
| `world/world_worker.inc` | `glue/tick/world_worker_shared.inc` | `world_hex` |

The Part column gives each part's path now; its old path is in [Every moved file](#every-moved-file).

## Adding a module

[Structure](structure.md#adding-a-module) gives the steps.

## Every moved file

Each file once, from its path at `38bd9dfe` to its path now. The copies above are new files, not moves.

<details><summary>233 moves</summary>

| Before | After |
| --- | --- |
| `docs/bike.md` | `docs/features/bike.md` |
| `docs/building.md` | `docs/dev/building.md` |
| `docs/challenges.md` | `docs/modes/challenges.md` |
| `docs/cut-enemies.md` | `docs/cut-content/cut-enemies.md` |
| `docs/cut-eve.md` | `docs/cut-content/cut-eve.md` |
| `docs/cut-scenes-and-menus.md` | `docs/cut-content/cut-scenes-and-menus.md` |
| `docs/doro-races.md` | `docs/features/doro-races.md` |
| `docs/ghost.md` | `docs/features/ghost.md` |
| `docs/how-it-works.md` | `docs/internals/README.md` |
| `docs/interface.md` | `docs/players/interface.md` |
| `docs/lily-signal.md` | `docs/modes/lily-signal.md` |
| `docs/matrix-xiii.md` | `docs/modes/matrix-xiii.md` |
| `docs/night-operation-previews.md` | `docs/modes/night-operation-previews.md` |
| `docs/night-operation-shop.md` | `docs/modes/night-operation-shop.md` |
| `docs/night-operation.md` | `docs/modes/night-operation.md` |
| `docs/playing-with-a-friend.md` | `docs/players/playing-with-a-friend.md` |
| `docs/saves.md` | `docs/players/saves.md` |
| `docs/sbo-lobby.md` | `docs/features/sbo-lobby.md` |
| `docs/settings.md` | `docs/players/settings.md` |
| `docs/shared-enemies.md` | `docs/features/shared-enemies.md` |
| `docs/shared-world.md` | `docs/features/shared-world.md` |
| `docs/story-together.md` | `docs/features/story-together.md` |
| `docs/story.md` | `docs/dev/story.md` |
| `docs/tests.md` | `docs/dev/tests.md` |
| `docs/troubleshooting.md` | `docs/players/troubleshooting.md` |
| `mod/StellarCoop/Scripts/commands/bike.lua` | `mod/StellarCoop/Scripts/bike/commands.lua` |
| `mod/StellarCoop/Scripts/commands/daynight.lua` | `mod/StellarCoop/Scripts/sky/commands.lua` |
| `mod/StellarCoop/Scripts/commands/fight.lua` | `mod/StellarCoop/Scripts/fight/commands.lua` |
| `mod/StellarCoop/Scripts/commands/keys.lua` | `mod/StellarCoop/Scripts/ui/kit/commands.lua` |
| `mod/StellarCoop/Scripts/commands/nightop.lua` | `mod/StellarCoop/Scripts/nightop/commands.lua` |
| `mod/StellarCoop/Scripts/commands/partner.lua` | `mod/StellarCoop/Scripts/partner/commands.lua` |
| `mod/StellarCoop/Scripts/commands/race.lua` | `mod/StellarCoop/Scripts/race/commands.lua` |
| `mod/StellarCoop/Scripts/commands/scenes.lua` | `mod/StellarCoop/Scripts/story/commands.lua` |
| `mod/StellarCoop/Scripts/commands/session.lua` | `mod/StellarCoop/Scripts/session/commands.lua` |
| `mod/StellarCoop/Scripts/commands/story.lua` | `mod/StellarCoop/Scripts/matrix13/commands.lua` |
| `mod/StellarCoop/Scripts/commands/world.lua` | `mod/StellarCoop/Scripts/world/commands.lua` |
| `mod/StellarCoop/Scripts/cut/chainspin.lua` | `mod/StellarCoop/Scripts/cut/eve/chainspin.lua` |
| `mod/StellarCoop/Scripts/cut/devmenu.lua` | `mod/StellarCoop/Scripts/cut/menus/devmenu.lua` |
| `mod/StellarCoop/Scripts/cut/emote.lua` | `mod/StellarCoop/Scripts/cut/eve/emote.lua` |
| `mod/StellarCoop/Scripts/cut/enemy.lua` | `mod/StellarCoop/Scripts/core/enemy.lua` |
| `mod/StellarCoop/Scripts/cut/flight.lua` | `mod/StellarCoop/Scripts/cut/eve/flight.lua` |
| `mod/StellarCoop/Scripts/cut/gardener.lua` | `mod/StellarCoop/Scripts/cut/enemies/gardener.lua` |
| `mod/StellarCoop/Scripts/cut/glide.lua` | `mod/StellarCoop/Scripts/cut/eve/glide.lua` |
| `mod/StellarCoop/Scripts/cut/leviathan.lua` | `mod/StellarCoop/Scripts/cut/enemies/leviathan.lua` |
| `mod/StellarCoop/Scripts/cut/lines.lua` | `mod/StellarCoop/Scripts/cut/scenes/lines.lua` |
| `mod/StellarCoop/Scripts/cut/lion.lua` | `mod/StellarCoop/Scripts/cut/enemies/lion.lua` |
| `mod/StellarCoop/Scripts/cut/lion_rows.lua` | `mod/StellarCoop/Scripts/core/lion_rows.lua` |
| `mod/StellarCoop/Scripts/cut/mailbox.lua` | `mod/StellarCoop/Scripts/cut/menus/mailbox.lua` |
| `mod/StellarCoop/Scripts/cut/scene.lua` | `mod/StellarCoop/Scripts/cut/scenes/scene.lua` |
| `mod/StellarCoop/Scripts/cut/tendril.lua` | `mod/StellarCoop/Scripts/cut/enemies/tendril.lua` |
| `mod/StellarCoop/Scripts/cut/wear.lua` | `mod/StellarCoop/Scripts/cut/eve/wear.lua` |
| `mod/StellarCoop/Scripts/session/arrival.lua` | `mod/StellarCoop/Scripts/lobby/arrival.lua` |
| `mod/StellarCoop/Scripts/session/group.lua` | `mod/StellarCoop/Scripts/group/group.lua` |
| `mod/StellarCoop/Scripts/session/halls_rows.lua` | `mod/StellarCoop/Scripts/lobby/halls_rows.lua` |
| `mod/StellarCoop/Scripts/session/saves.lua` | `mod/StellarCoop/Scripts/save/saves.lua` |
| `mod/StellarCoop/Scripts/session/sbo.lua` | `mod/StellarCoop/Scripts/lobby/sbo.lua` |
| `mod/StellarCoop/Scripts/session/sbo_maps.lua` | `mod/StellarCoop/Scripts/lobby/sbo_maps.lua` |
| `mod/StellarCoop/Scripts/session/travel.lua` | `mod/StellarCoop/Scripts/group/travel.lua` |
| `mod/StellarCoop/Scripts/story/subtitles.lua` | `mod/StellarCoop/Scripts/matrix13/quest/subtitles.lua` |
| `mod/StellarCoop/Scripts/ui/create.lua` | `mod/StellarCoop/Scripts/session/ui/create.lua` |
| `mod/StellarCoop/Scripts/ui/create_model.lua` | `mod/StellarCoop/Scripts/session/ui/create_model.lua` |
| `mod/StellarCoop/Scripts/ui/guide.lua` | `mod/StellarCoop/Scripts/ui/kit/guide.lua` |
| `mod/StellarCoop/Scripts/ui/guide_text.lua` | `mod/StellarCoop/Scripts/ui/text/guide.lua` |
| `mod/StellarCoop/Scripts/ui/kit.lua` | `mod/StellarCoop/Scripts/ui/kit/kit.lua` |
| `mod/StellarCoop/Scripts/ui/lobby.lua` | `mod/StellarCoop/Scripts/lobby/ui/lobby.lua` |
| `mod/StellarCoop/Scripts/ui/lobby_model.lua` | `mod/StellarCoop/Scripts/lobby/ui/lobby_model.lua` |
| `mod/StellarCoop/Scripts/ui/menu.lua` | `mod/StellarCoop/Scripts/ui/kit/menu.lua` |
| `mod/StellarCoop/Scripts/ui/model.lua` | `mod/StellarCoop/Scripts/ui/kit/model.lua` |
| `mod/StellarCoop/Scripts/ui/notice.lua` | `mod/StellarCoop/Scripts/ui/kit/notice.lua` |
| `mod/StellarCoop/Scripts/ui/parts.lua` | `mod/StellarCoop/Scripts/ui/kit/parts.lua` |
| `mod/StellarCoop/Scripts/ui/pause_tab.lua` | `mod/StellarCoop/Scripts/ui/kit/pause_tab.lua` |
| `mod/StellarCoop/Scripts/ui/region_tabs.lua` | `mod/StellarCoop/Scripts/group/region_tabs.lua` |
| `mod/StellarCoop/Scripts/ui/sessions.lua` | `mod/StellarCoop/Scripts/session/ui/sessions.lua` |
| `mod/StellarCoop/Scripts/ui/sessions_model.lua` | `mod/StellarCoop/Scripts/session/ui/sessions_model.lua` |
| `native/src/fight/pilot.h` | `native/src/game/pilot.h` |
| `native/src/fight/pvp.h` | `native/src/game/pvp.h` |
| `native/src/fight/spawn_sync.h` | `native/src/game/spawn_sync.h` |
| `native/src/fight/sync.h` | `native/src/game/fight/sync.h` |
| `native/src/fight/types.h` | `native/src/game/types.h` |
| `native/src/game/debug_keys.h` | `native/src/cut/debug_keys.h` |
| `native/src/game/items.h` | `native/src/cut/items.h` |
| `native/src/game/loading.h` | `native/src/lobby/loading.h` |
| `native/src/game/options.h` | `native/src/session/options.h` |
| `native/src/game/pad.h` | `native/src/ui/pad.h` |
| `native/src/game/pak_list.h` | `native/src/link/pak_list.h` |
| `native/src/game/pause_tab.h` | `native/src/ui/pause_tab.h` |
| `native/src/game/photo_freeze.h` | `native/src/photo/photo_freeze.h` |
| `native/src/game/preset.h` | `native/src/lobby/preset.h` |
| `native/src/game/region_tabs.h` | `native/src/group/region_tabs.h` |
| `native/src/game/sky.h` | `native/src/sky/sky.h` |
| `native/src/glue/tick/anim_game.inc` | `native/src/cut/anim_game.inc` |
| `native/src/glue/tick/anim_worker.inc` | `native/src/cut/anim_worker.inc` |
| `native/src/glue/tick/bike_game.inc` | `native/src/bike/bike_game.inc` |
| `native/src/glue/tick/bike_worker.inc` | `native/src/bike/bike_worker.inc` |
| `native/src/glue/tick/camp_text_game.inc` | `native/src/matrix13/camp_text_game.inc` |
| `native/src/glue/tick/camps_game.inc` | `native/src/group/camps_game.inc` |
| `native/src/glue/tick/cycle_game.inc` | `native/src/lobby/cycle_game.inc` |
| `native/src/glue/tick/debug_game.inc` | `native/src/cut/debug_game.inc` |
| `native/src/glue/tick/debug_worker.inc` | `native/src/cut/debug_worker.inc` |
| `native/src/glue/tick/fight_game.inc` | `native/src/fight/fight_game.inc` |
| `native/src/glue/tick/fight_worker.inc` | `native/src/fight/fight_worker.inc` |
| `native/src/glue/tick/freeze_game.inc` | `native/src/photo/freeze_game.inc` |
| `native/src/glue/tick/freeze_worker.inc` | `native/src/photo/freeze_worker.inc` |
| `native/src/glue/tick/guard_text_game.inc` | `native/src/nightop/guard_text_game.inc` |
| `native/src/glue/tick/hud_game.inc` | `native/src/lobby/hud_game.inc` |
| `native/src/glue/tick/hud_worker.inc` | `native/src/lobby/hud_worker.inc` |
| `native/src/glue/tick/items_worker.inc` | `native/src/cut/items_worker.inc` |
| `native/src/glue/tick/lion_game.inc` | `native/src/lion/lion_game.inc` |
| `native/src/glue/tick/loading_game.inc` | `native/src/lobby/loading_game.inc` |
| `native/src/glue/tick/loading_worker.inc` | `native/src/lobby/loading_worker.inc` |
| `native/src/glue/tick/nightop_game.inc` | `native/src/nightop/nightop_game.inc` |
| `native/src/glue/tick/nightop_worker.inc` | `native/src/nightop/nightop_worker.inc` |
| `native/src/glue/tick/options_game.inc` | `native/src/session/options_game.inc` |
| `native/src/glue/tick/options_worker.inc` | `native/src/session/options_worker.inc` |
| `native/src/glue/tick/pad_game.inc` | `native/src/ui/pad_game.inc` |
| `native/src/glue/tick/pad_worker.inc` | `native/src/ui/pad_worker.inc` |
| `native/src/glue/tick/pause_tab_game.inc` | `native/src/ui/pause_tab_game.inc` |
| `native/src/glue/tick/pause_tab_worker.inc` | `native/src/ui/pause_tab_worker.inc` |
| `native/src/glue/tick/pilot_game.inc` | `native/src/fight/pilot_game.inc` |
| `native/src/glue/tick/pose_game.inc` | `native/src/pose/pose_game.inc` |
| `native/src/glue/tick/quests_game.inc` | `native/src/quest/quests_game.inc` |
| `native/src/glue/tick/quests_worker.inc` | `native/src/quest/quests_worker.inc` |
| `native/src/glue/tick/region_tabs_worker.inc` | `native/src/group/region_tabs_worker.inc` |
| `native/src/glue/tick/saves_worker.inc` | `native/src/save/saves_worker.inc` |
| `native/src/glue/tick/sbo_game.inc` | `native/src/lobby/sbo_game.inc` |
| `native/src/glue/tick/sbo_worker.inc` | `native/src/lobby/sbo_worker.inc` |
| `native/src/glue/tick/shortcut_game.inc` | `native/src/save/shortcut_game.inc` |
| `native/src/glue/tick/shortcut_worker.inc` | `native/src/save/shortcut_worker.inc` |
| `native/src/glue/tick/sky_game.inc` | `native/src/sky/sky_game.inc` |
| `native/src/glue/tick/sky_worker.inc` | `native/src/sky/sky_worker.inc` |
| `native/src/glue/tick/story_game.inc` | `native/src/story/story_game.inc` |
| `native/src/glue/tick/story_worker.inc` | `native/src/story/story_worker.inc` |
| `native/src/glue/tick/travel_game.inc` | `native/src/group/travel_game.inc` |
| `native/src/glue/tick/travel_worker.inc` | `native/src/group/travel_worker.inc` |
| `native/src/glue/tick/warp_game.inc` | `native/src/group/warp_game.inc` |
| `native/src/glue/tick/world_game.inc` | `native/src/world/world_game.inc` |
| `native/src/glue/tick/world_worker.inc` | `native/src/world/world_worker.inc` |
| `native/src/pose/codec.h` | `native/src/game/codec.h` |
| `native/src/pose/core.h` | `native/src/game/core.h` |
| `native/src/pose/engine.h` | `native/src/game/pose/engine.h` |
| `native/src/pose/stream.h` | `native/src/game/stream.h` |
| `native/src/pose/table.h` | `native/src/game/table.h` |
| `native/src/quest/engine.h` | `native/src/game/quest/engine.h` |
| `native/src/quest/sync.h` | `native/src/game/quest/sync.h` |
| `native/src/save/rotation.h` | `native/src/game/rotation.h` |
| `native/src/save/sbo_record.h` | `native/src/game/sbo_record.h` |
| `native/src/save/shortcut.h` | `native/src/game/shortcut.h` |
| `native/src/save/shortcut_load.h` | `native/src/game/shortcut_load.h` |
| `native/src/save/slot.h` | `native/src/game/slot.h` |
| `native/src/save/twins.h` | `native/src/game/twins.h` |
| `native/src/story/engine.h` | `native/src/game/story/engine.h` |
| `native/src/story/rows.h` | `native/src/game/story/rows.h` |
| `native/src/story/sync.h` | `native/src/game/story/sync.h` |
| `native/src/world/engine.h` | `native/src/game/world/engine.h` |
| `native/src/world/rows.h` | `native/src/game/world/rows.h` |
| `native/src/world/sync.h` | `native/src/game/world/sync.h` |
| `tests/lua/commands/session_test.lua` | `tests/lua/session/commands_test.lua` |
| `tests/lua/cut/chainspin_test.lua` | `tests/lua/cut/eve/chainspin_test.lua` |
| `tests/lua/cut/devmenu_test.lua` | `tests/lua/cut/menus/devmenu_test.lua` |
| `tests/lua/cut/emote_test.lua` | `tests/lua/cut/eve/emote_test.lua` |
| `tests/lua/cut/enemy_test.lua` | `tests/lua/core/enemy_test.lua` |
| `tests/lua/cut/flight_test.lua` | `tests/lua/cut/eve/flight_test.lua` |
| `tests/lua/cut/gardener_test.lua` | `tests/lua/cut/enemies/gardener_test.lua` |
| `tests/lua/cut/glide_test.lua` | `tests/lua/cut/eve/glide_test.lua` |
| `tests/lua/cut/leviathan_test.lua` | `tests/lua/cut/enemies/leviathan_test.lua` |
| `tests/lua/cut/lines_test.lua` | `tests/lua/cut/scenes/lines_test.lua` |
| `tests/lua/cut/lion_test.lua` | `tests/lua/cut/enemies/lion_test.lua` |
| `tests/lua/cut/mailbox_test.lua` | `tests/lua/cut/menus/mailbox_test.lua` |
| `tests/lua/cut/scene_test.lua` | `tests/lua/cut/scenes/scene_test.lua` |
| `tests/lua/cut/tendril_test.lua` | `tests/lua/cut/enemies/tendril_test.lua` |
| `tests/lua/cut/wear_test.lua` | `tests/lua/cut/eve/wear_test.lua` |
| `tests/lua/main/cycle_test.lua` | `tests/lua/session/wiring_cycle_test.lua` |
| `tests/lua/main/daynight_test.lua` | `tests/lua/sky/wiring_test.lua` |
| `tests/lua/main/dlc_test.lua` | `tests/lua/session/wiring_dlc_test.lua` |
| `tests/lua/main/fight_notices_test.lua` | `tests/lua/fight/wiring_notices_test.lua` |
| `tests/lua/main/fight_test.lua` | `tests/lua/fight/wiring_test.lua` |
| `tests/lua/main/quests_test.lua` | `tests/lua/quest/wiring_test.lua` |
| `tests/lua/main/sbo_test.lua` | `tests/lua/lobby/wiring_test.lua` |
| `tests/lua/main/scenes_test.lua` | `tests/lua/story/wiring_test.lua` |
| `tests/lua/main/story_test.lua` | `tests/lua/story/wiring_dump_test.lua` |
| `tests/lua/main/world_test.lua` | `tests/lua/world/wiring_test.lua` |
| `tests/lua/session/arrival_test.lua` | `tests/lua/lobby/arrival_test.lua` |
| `tests/lua/session/group_test.lua` | `tests/lua/group/group_test.lua` |
| `tests/lua/session/halls_rows_test.lua` | `tests/lua/lobby/halls_rows_test.lua` |
| `tests/lua/session/saves_test.lua` | `tests/lua/save/saves_test.lua` |
| `tests/lua/session/sbo_test.lua` | `tests/lua/lobby/sbo_test.lua` |
| `tests/lua/session/travel_test.lua` | `tests/lua/group/travel_test.lua` |
| `tests/lua/story/subtitles_test.lua` | `tests/lua/matrix13/quest/subtitles_test.lua` |
| `tests/lua/ui/create_model_test.lua` | `tests/lua/session/ui/create_model_test.lua` |
| `tests/lua/ui/create_test.lua` | `tests/lua/session/ui/create_test.lua` |
| `tests/lua/ui/guide_test.lua` | `tests/lua/ui/kit/guide_test.lua` |
| `tests/lua/ui/kit_test.lua` | `tests/lua/ui/kit/kit_test.lua` |
| `tests/lua/ui/lobby_model_test.lua` | `tests/lua/lobby/ui/lobby_model_test.lua` |
| `tests/lua/ui/lobby_test.lua` | `tests/lua/lobby/ui/lobby_test.lua` |
| `tests/lua/ui/model_test.lua` | `tests/lua/ui/kit/model_test.lua` |
| `tests/lua/ui/notice_test.lua` | `tests/lua/ui/kit/notice_test.lua` |
| `tests/lua/ui/pause_tab_test.lua` | `tests/lua/ui/kit/pause_tab_test.lua` |
| `tests/lua/ui/region_tabs_test.lua` | `tests/lua/group/region_tabs_test.lua` |
| `tests/lua/ui/sessions_model_test.lua` | `tests/lua/session/ui/sessions_model_test.lua` |
| `tests/lua/ui/sessions_test.lua` | `tests/lua/session/ui/sessions_test.lua` |
| `tests/native/fight/pilot_test.cpp` | `tests/native/game/pilot_test.cpp` |
| `tests/native/fight/pvp_test.cpp` | `tests/native/game/pvp_test.cpp` |
| `tests/native/fight/spawn_sync_test.cpp` | `tests/native/game/spawn_sync_test.cpp` |
| `tests/native/fight/sync_test.cpp` | `tests/native/game/fight/sync_test.cpp` |
| `tests/native/game/debug_keys_test.cpp` | `tests/native/cut/debug_keys_test.cpp` |
| `tests/native/game/items_test.cpp` | `tests/native/cut/items_test.cpp` |
| `tests/native/game/loading_test.cpp` | `tests/native/lobby/loading_test.cpp` |
| `tests/native/game/options_test.cpp` | `tests/native/session/options_test.cpp` |
| `tests/native/game/pad_test.cpp` | `tests/native/ui/pad_test.cpp` |
| `tests/native/game/pak_list_test.cpp` | `tests/native/link/pak_list_test.cpp` |
| `tests/native/game/pause_tab_test.cpp` | `tests/native/ui/pause_tab_test.cpp` |
| `tests/native/game/photo_freeze_test.cpp` | `tests/native/photo/photo_freeze_test.cpp` |
| `tests/native/game/preset_test.cpp` | `tests/native/lobby/preset_test.cpp` |
| `tests/native/game/region_tabs_test.cpp` | `tests/native/group/region_tabs_test.cpp` |
| `tests/native/game/sky_test.cpp` | `tests/native/sky/sky_test.cpp` |
| `tests/native/pose/codec_test.cpp` | `tests/native/game/codec_test.cpp` |
| `tests/native/pose/engine_test.cpp` | `tests/native/game/pose/engine_test.cpp` |
| `tests/native/pose/stream_test.cpp` | `tests/native/game/stream_test.cpp` |
| `tests/native/pose/table_test.cpp` | `tests/native/game/table_test.cpp` |
| `tests/native/quest/engine_test.cpp` | `tests/native/game/quest/engine_test.cpp` |
| `tests/native/quest/sync_test.cpp` | `tests/native/game/quest/sync_test.cpp` |
| `tests/native/save/rotation_test.cpp` | `tests/native/game/rotation_test.cpp` |
| `tests/native/save/sbo_record_test.cpp` | `tests/native/game/sbo_record_test.cpp` |
| `tests/native/save/shortcut_load_test.cpp` | `tests/native/game/shortcut_load_test.cpp` |
| `tests/native/save/shortcut_test.cpp` | `tests/native/game/shortcut_test.cpp` |
| `tests/native/save/slot_test.cpp` | `tests/native/game/slot_test.cpp` |
| `tests/native/save/twins_test.cpp` | `tests/native/game/twins_test.cpp` |
| `tests/native/story/engine_test.cpp` | `tests/native/game/story/engine_test.cpp` |
| `tests/native/story/rows_test.cpp` | `tests/native/game/story/rows_test.cpp` |
| `tests/native/story/sync_test.cpp` | `tests/native/game/story/sync_test.cpp` |
| `tests/native/world/engine_test.cpp` | `tests/native/game/world/engine_test.cpp` |
| `tests/native/world/rows_test.cpp` | `tests/native/game/world/rows_test.cpp` |
| `tests/native/world/sync_test.cpp` | `tests/native/game/world/sync_test.cpp` |

</details>
