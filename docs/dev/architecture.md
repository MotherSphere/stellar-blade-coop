# Architecture

The other internals pages go feature by feature, each beside its player page; [How it
works](../README.md#how-stellar-blade-online-works) lists them. The repository layout is in
[Building](building.md#repository-layout).

## Lua and native parts

Stellar Blade Online has two parts, both in the mod folder `Mods/StellarCoop/`:

- The Lua part (`Scripts/*.lua`), run by UE4SS on the game thread. It uses UE4SS's object API to read what EVE is made
  of, build the ghost's actor and place it, draw the co-op menu, the chat and your friend's card, marker and arrow,
  show notices, and handle the console and the keys.
- The native part (`StellarCoop.dll`), loaded by the Lua script with `package.loadlib`. It has three entry points:
  - a worker thread, started when Windows loads the DLL. It makes every Steam call, reads and writes the files shared
    with Lua, sends and receives tables and poses, and writes the logs.
  - `coop_tick`, an exported function that the Lua loop calls once per frame on the game thread. It reads and encodes
    EVE's pose from engine memory, decodes the poses that came back and writes the ghost's bones. Every 100 ms it also
    writes the [day and night cycle](../world/daynight-internals.md)'s light into the world's env settings.
  - `coop_pad`, an exported function that the Lua loop calls each frame for the controller's events (see
    [Controller](#controller)).
  - `coop_pause_close`, an exported function that Lua calls on the game thread when the pause menu's Online tab closes
    the pause menu. It runs the game's own close, the one Back uses (see [Pause
    menu](../players/interface.md#pause-menu)).

```
   your game                                                      friend's game
   ---------                                                      -------------
   capture.lua --coop-components.txt--> worker --table (reliable)-----> worker --coop-remote.txt--> puppet.lua
                                          ^                                |                     builds the ghost
   coop_tick reads EVE's pose ---encode---+---pose (unreliable)----------->+--decode, playback--> coop_tick writes
                                              Steam channel 1                                    the ghost's bones
```

Both games run the same pipeline in both directions, so each player sees the other's ghost.

### The Lua scripts

| Script | Role |
| --- | --- |
| `main.lua` | Entry point: the state table `M` the runtime and the modules share, the module list (`MODULES`), then the runtime's files in order and the `Loaded version` line |
| `main/boot.lua` | Loads the DLL and its entry points, starts the Steam link's Lua side, reads the settings, writes a new session token |
| `main/base.lua` | What the runtime and the modules share: notices, words, `ask`, the co-op save check, `riding()` and the plain values several files read (`chat_clock`, `at_title` and the rest) |
| `main/loader.lua` | The module loader: each module's `wiring.lua` in list order, the stubs, the off line and its notice, the build steps, `view` and `get` (see [Modules and isolation](#modules-and-isolation)) |
| `main/commands.lua` | `coop ui` and `coop off`, `coop guide` and `coop keys` from `ui/kit/commands.lua`, then `report` and `run`, which every `coop` word goes through |
| `main/ui.lua` | The UI kit, the guide and the menu (`ui/kit/menu.lua`), with each module's build steps between them in the kit's build order |
| `main/input.lua` | The frame and pass timing line, the pad's events routed to the open screen, the Online tab, the console command |
| `main/frame.lua` | The frame loop: each module's frame work under `guarded()`, the UI's ticks and the pad's events |
| `main/pass.lua` | The 250 ms loop, with the Steam link only: each module's pass work under `guarded()`, the link's notices and the off notices |
| `main/keys.lua` | The key binds, with the Steam link only: the F-keys, Enter, the navigation keys, Esc and the mouse buttons |
| `<module>/wiring.lua` | A module's manifest: the modules it reads later (`uses`), the `M` fields it sets (`exports`), its share of the startup (`new`) and its kit groups (`build`) |
| `<module>/commands.lua` | A module's `coop` words: its `new` returns them and the loader adds them to `M.commands` |
| `online/session/commands.lua` | The session's `coop` commands: `host` (the Create a session screen, or a host at once with a Who can join word), `invite`, `join` (a lobby id, a join code or a row of the session list), `list`, `leave`, `status`, `report`, `copy`, `mark`, `allow`, `deny`, `remove`, `mute`, `unmute`, `block`, `unblock` and `blocked` |
| `online/group/commands.lua` | `coop revive test` and `coop travel` |
| `online/lobby/commands.lua` | `coop match` and `coop sbo`, with its own copy of `coop join` for `coop match join` |
| `online/saves/commands.lua` | `coop saves` and `coop shortcut` |
| `online/partner/commands.lua` | The ghost's `coop` commands: `puppet`, `basesuit`, `where`, `near`, `cns`, `look`, `loopback`, `record` and `replay` |
| `online/photo/commands.lua` | `coop freeze` |
| `online/modes/nightop/commands.lua` | `coop no`, `coop nightop`, `coop challenge` and `coop recruiter`, with their co-op save check |
| `online/modes/race/commands.lua` | `coop race`: the Doro look and probe, and the co-op save check before `online/modes/race/run.lua`'s command |
| `fight/enemies/commands.lua` | `coop fight` (its pilot and spawn probe included) and `coop pvp`: their lines for the native part |
| `story/quests/commands.lua` | `coop quests`: its lines for the native part |
| `fight/bosses/commands.lua` | `coop leviathan` and the other viewer commands (`gardener`, `tendril`, `mann`, `nier`, `orcal`, `enya`), with the co-op save check before `show` and before `cam` turns the camera on; `coop lion`, with the co-op save check before the words that spawn; `coop gardener fight`, handed to `fight/bosses/gardener.lua` with the co-op save check and the viewer's display put away before the words that spawn; `coop tendril fight`, handed to `fight/bosses/tendril.lua` the same way |
| `eve/commands.lua` | `coop wear`; `coop emote`; `coop fly`, `coop slowmo` and `coop glide`, with the co-op save check before `on`; `coop chainspin` |
| `story/scenes/commands.lua` | `coop scene`, with the co-op save check before a scene's name (`coop scene lily` handed to `world/maps/matrix13/quest/on_time.lua`'s talk); `coop lines` |
| `cutmenus/commands.lua` | `coop gift`, with the co-op save check before every word; `coop devmenu` and `coop devinfo` |
| `world/maps/matrix13/commands.lua` | `coop mxiii` and `coop lily` |
| `ui/kit/commands.lua` | `coop guide` (it opens the guide) and `coop keys reset` |
| `world/objects/commands.lua` | `coop world`: on and off for the [shared world](../world/objects-internals.md) until the mod reloads, and its status line |
| `story/together/commands.lua` | `coop scenes`: on and off for [story together](../story/together-internals.md) until the mod reloads; its status line. `coop story`, handed to `story/together/snapshot.lua` |
| `world/daynight/commands.lua` | `coop daynight`: its words handed to `world/daynight/daynight.lua` ([Day and night](../world/daynight-internals.md)) |
| `vehicles/bike/commands.lua` | `coop bike`, `coop bike status` and `coop bike tune`, handed to `vehicles/bike/ride.lua` ([The bike](../vehicles/bike-internals.md)) |
| `world/teamshop/commands.lua` | `coop teamshop`: handed to `world/teamshop/shop.lua` ([Team shop](../world/teamshop.md)) |
| `vehicles/bike/ride.lua` | The bike on EVE: the preload asked of the native part, the bike part on her actor, the checks, the mount and the dismount in their order with `coop-bike.txt`, the gate, the riding pose kept playing, the lean on her main mesh ([The bike](../vehicles/bike-internals.md)) |
| `vehicles/bike/model.lua` | The bike's riding model, adapted from Eve On Wheels by dCharisma1, in `vehicles/bike/drive_model.lua`'s table shape so `vehicles/bike/drive.lua` drives it ([Riding](../vehicles/bike-internals.md#riding)). Both are the bike's copies of the races' `online/modes/race/drive_model.lua` and `online/modes/race/drive.lua` |
| `world/daynight/rule.lua` | The day and night cycle's map table and rules, the native status line's `sky=` reader, the command's hour, with no engine call ([Day and night](../world/daynight-internals.md)) |
| `world/daynight/daynight.lua` | The day and night cycle in the 250 ms pass: the `sky` request on change, the sky dressing (domes, SkyCreator time, SBO's star layer, Xion's night dome) and the lights of SBO's own maps, all put back at an off, with their originals kept in `coop-sky.txt` for a Lua reload ([Day and night](../world/daynight-internals.md)) |
| `core/link.lua` | The Lua side of the shared files, `coop-settings.txt`, the status key's summary |
| `online/partner/capture.lua` | EVE's capture: what a ghost of her is made of (read only) |
| `online/partner/puppet.lua` | The ghost: builds it from a table, places it, its name tag, effects, its Doro mode in a race, `coop where` |
| `ui/kit/notice.lua` | The line of notices above your EVE, used while the on-screen UI is not up |
| `online/session/chat.lua` | The session chat: its history (memory only), the feed of chat lines and notices, and the text box |
| `online/session/join.lua` | The code box. The join popups on SB's `WB_Common_Popup` with a kit panel as fallback: the host's question about a player who asks to join, the joiner's wait for the host's answer. The feed's join and leave lines in SB's words |
| `online/lobby/sbo.lua` | The SBO lobby (`sbo_lobby`), in Xion or, with the hall lobby pak, in one of the five hall lobbies of `online/lobby/sbo_maps.lua`: where it is, its eight spots and fence, the table rows it edits and puts back, the checks before the recruiter's Join takes you there, its menu camera (Xion's at the Agit, each hall's in the hall), and the hall seats: at each hall arrival it spawns SB's chair blueprint at every seat with a row; SB binds the chair to that seat's `ZoneEnvSpawnTable` row, then shows its Rest prompt and seats EVE itself. The menu key sits EVE only on a seat within 1.5 m where no chair bound, and on the two Cloister camp seats, with her collision off and her movement held. Another player's EVE on a seat does not block it. On stand-up it teleports EVE to the seat's approach point before her collision and walking come back |
| `online/lobby/arrival.lua` | The hold at each SBO lobby arrival: from the new world's player controller until the lobby is ready, Stellar Blade's own black screen covers the hall and the on-screen UI stays hidden, then the black fades out over the open lobby menu; the time-outs that lift it whatever is missing. No engine call |
| `online/partner/hud.lua` | Your friend's card, marker and off-screen arrow |
| `ui/kit/hud_parts.lua` | The maths that places your friend's marker and arrow, the distance, whether she is on your map and her gauges, with no engine call; the partner HUD, the kit, the race's HUD and the fight's notices read it |
| `online/session/booth.lua` | The camp phone booths near EVE, for the co-op line |
| `ui/kit/menu.lua` | The co-op menu: draws its pages, takes its keys, runs its rows as `coop` commands, writes and applies settings |
| `ui/kit/model.lua` | The menu's rows and settings, with no engine call |
| `online/lobby/ui/lobby_model.lua` | The SBO lobby menu's rows, status and members by lobby state, and its settings screen's rows, with no engine call |
| `online/lobby/ui/lobby.lua` | The SBO lobby menu and its settings screen drawn with Stellar Blade's own widget parts, the Leave question, the countdown and the waiting room's line |
| `ui/kit/parts.lua` | Stellar Blade's widget parts that the lobby's screens, the Sessions screen, the Create a session screen and the join popups make: their classes, specs and the calls that make and drive them, each refusal logged once |
| `online/session/ui/sessions_model.lua` | The Sessions screen's rows, status line, Refresh and Select from the native part's session list, with no engine call |
| `online/session/ui/sessions.lua` | The Sessions screen (Find a session) drawn with Stellar Blade's own widget parts: its two tabs, rows, details pane and key hints |
| `online/session/ui/create_model.lua` | The Create a session screen's rows (Who can join and the session rules, Options' own settings), with no engine call |
| `online/session/ui/create.lua` | The Create a session screen (Host a session) drawn with Stellar Blade's own widget parts; Start hosts |
| `ui/kit/guide.lua` | The first-launch guide: its pages, keys, mouse and pad, `coop-guide.txt`, and the Mother Sphere art imported from `Assets/MotherSphere.png` at run time (`ImportFileAsTexture2D`) |
| `ui/text/guide.lua` | The guide's words and its menu row's, in the same languages as `ui/text.lua` |
| `ui/text.lua`, `ui/text/en.lua` and the other languages | The words of the menu, the chat, the partner HUD, the co-op saves, the join codes, the status line, the Doro race's HUD and the notices written in Lua, in the game's 23 text languages: one table per language in `ui/text/`, gathered by `ui/text.lua`, which picks the game language's table. Each table's `modules` holds the modules' names the off notice uses |
| `ui/kit/kit.lua` | The UI kit (runtime UMG widgets in the game's look) that draws the menu, the chat and the partner HUD |
| `core/keybind.lua` | The key settings' grammar and their clash check |
| `core/settings_file.lua` | Rewrites one line of `coop-settings.txt` and keeps the rest of the file |
| `core/ue4ss_settings.lua` | Checks `HookBeginPlay` and `bUseUObjectArrayCache` in `UE4SS-settings.ini` (read only) |
| `online/modes/nightop/probe.lua` | The `coop no` probe, and the heal that a Night Operation run or a challenge fires |
| `online/modes/nightop/waves.lua` | The run's waves, keys, score, timers and states, read from a definition, alone or for two players, the pairing of new bodies with their spawn spots, a spot moved onto the navmesh through navmesh calls it is given (`W.settle`), and the night line's two formats, with no engine call |
| `online/modes/nightop/run.lua` | The `coop nightop` run and the `coop challenge` runs: start checks, the host's ask and the guest's answer, spawns and the navmesh calls that settle their spots, the monsters it tracks, a co-op run's down and revive, the night line, its card and result panel |
| `online/modes/nightop/shop.lua` | Night Operation's reward shop: the points file, `coop nightop shop` and `buy`, and its one item request |
| `online/modes/nightop/challenges.lua` | The challenges' waves and rules, the `coop challenge` list and the best runs in `coop-records.txt`, with no engine call |
| `online/modes/nightop/board.lua` | The Shooting Range's score on the cut test widget `WB_ShootingTrainingTest`, beside the run's card |
| `online/modes/nightop/recruiter.lua` | The `coop recruiter` preview |
| `online/modes/nightop/recruiter_text.lua` | The recruiter's lines in the game's 23 languages |
| `ui/text/culture.lua` | `culture()`, the game language's culture for the text tables, the guide's words, the lobby and Matrix XIII |
| `online/modes/nightop/guard_text.lua` | The recruiter's lines for the native part: the game language's seven lines as one `guardtext` request, sent again when the language changes, and the `[RC] text:` line |
| `online/modes/race/doro.lua` | The display Doro (a plain actor with Doro's mesh, animated by the engine's single-node animation, made through `core/actors.lua`), the Doro look on your EVE, and `coop race probe doro` |
| `online/modes/race/model.lua` | Doro races with no engine call: the track file, the rules, the start slots, the host's and the guest's race over the race lines, and the ranking |
| `online/modes/race/run.lua` | Doro races in game: recording a track, the race run from EVE's feet, its HUD, its Doros and its notices |
| `fight/bosses/leviathan.lua` | `coop leviathan` and the other viewer commands: one table of seven cut models (Naytibas 10, 1 and 6, the early Mann, the NieR machines, Orcal's and Enya's prototypes: their meshes, animations, default distance, height and scale, skins) and one viewer for them. It reads a creature's assets and CharacterTable rows, shows one of its meshes playing its animations on a display like the Doro's (one creature at a time) and flies a free camera to film it |
| `fight/bosses/enemy.lua` | The cut enemies' copy of `core/enemy.lua`: the flow `coop lion`, `coop gardener fight` and `coop tendril fight` share, each from its own spec: a batch's rows asked of the native part and read back, the spawn, the entrance on a display copy, the material and the boss bar's name, the lines that follow the body ([The cut Lion](../fight/bosses-internals.md#the-cut-lion)) |
| `core/enemy.lua` | The same flow as the cut enemies' copy; Matrix XIII's batches (`world/maps/matrix13/level/travel.lua`, `world/maps/matrix13/quest/on_time.lua`) and the hall lobbies' (`online/lobby/halls_rows.lua`) use its rows part only |
| `fight/bosses/lion.lua` | `coop lion`: the Lion's spec for `fight/bosses/enemy.lua` and its own parts (the anim instance repair, `unfreeze`, `brain`, `control`); `Lion.rows`, the lion rows batch for the shop's stimpacks and `coop chainspin`, or the bolt rows batch for the shop's Shock Bolt ([The cut Shock Bolt](../online/modes/nightop-shop-internals.md#the-cut-shock-bolt)) |
| `fight/bosses/gardener.lua` | `coop gardener fight`: the Gardener's spec for `fight/bosses/enemy.lua` ([The cut Gardener](../fight/bosses-internals.md#the-cut-gardener)) |
| `fight/bosses/tendril.lua` | `coop tendril fight`: the Tendril's spec for `fight/bosses/enemy.lua` and the Shows of its clips, built in memory ([The cut Tendril](../fight/bosses-internals.md#the-cut-tendril)) |
| `world/maps/matrix13/level/travel.lua` | `coop mxiii [30\|leave\|boss]`: the test pak's check (v1 to v5, the `.ucas` read window by window through the `.utoc`'s block table; anything before v5 refused), Matrix XIII's camp batch through `core/enemy.lua`'s rows part, then the follow's camp travel to `DLC02_00_Camp_00`, or with 30 to `DLC02_30_Camp_01`; at the title its four batches and the Lion's and the Gardener's ([Matrix XIII: how it works](../world/matrix13-internals.md)) |
| `world/maps/matrix13/level/rows.lua` | Matrix XIII's rows as `world/maps/matrix13/mxiii_rows.h` writes them, the ladders, ledges and ropes, the boxes and barrels, the boss points and `coop mxiii warp`'s points, written by `tools/mxiii_rows.py` ([Matrix XIII's world rows](../world/matrix13-internals.md#matrix-xiiis-world-rows)) |
| `world/maps/matrix13/level/mila.lua` | Mila's body, a display only (`core/actors.lua`): Kara's mesh in the sitting clip at the cooked markers, placed by `zone_talks.lua` after scenes 4E and 4N ([Lily's signal](../world/lily-signal-internals.md)) |
| `world/maps/matrix13/level/breakables.lua` | In world 2800: the 317 boxes and barrels spawned at run time in place of the cooked proxies, which it hides ([Matrix XIII's world rows](../world/matrix13-internals.md#matrix-xiiis-world-rows)) |
| `world/maps/matrix13/level/move.lua`, `world/maps/matrix13/level/boss.lua`, `world/maps/matrix13/level/fans.lua` | In world 2800: the ladders, ledges and ropes spawned at run time, the fixes on the Lion and Gardener the game spawns from their rows, with `coop mxiii boss` as the key-0 fallback, and the fan rotors held still until their levers read On ([Matrix XIII's world rows](../world/matrix13-internals.md#matrix-xiiis-world-rows)) |
| `world/maps/matrix13/quest/on_time.lua`, `world/maps/matrix13/quest/text.lua`, `world/maps/matrix13/culture.lua`, `world/maps/matrix13/words.lua` | Lily's signal: the signal rows asked and read back, the words written (again when the game's language changes), the prologue's acquire, her choice list's swap asked on and off with its two labels, the picks, the talks, the quests' asks and `coop mxiii`'s travel, the M01 fallback, the drive room check and `coop lily signal\|talk\|hold` ([Lily's signal](../world/lily-signal-internals.md)); `culture.lua` maps the game's culture to one of its 23 text languages (`ui/text/culture.lua`) for the words, the talks and the names; `words.lua` gives a line of the 21 languages past English and French by its source id |
| `world/maps/matrix13/talks/prologue.lua`, `arrival.lua`, `finale.lua`, `zone1.lua` to `zone4.lua` | The talks' lines, one module per talk and one per zone (1A to 1E, 2A to 2G, 3A to 3K, 4A to 4N), each line its speaker, English and French |
| `world/maps/matrix13/text/<language>.lua` | Matrix XIII's words in the 21 languages past English and French, by source id. Generated, never edited by hand. |
| `world/maps/matrix13/quest/zone_talks.lua` | The zone talks in game: a trigger for each of the 36 scenes, the order rules, the fight gate, one file per co-op slot for the played scenes ([Lily's signal](../world/lily-signal-internals.md)) |
| `world/maps/matrix13/quest/subtitles.lua` | Lily's talks: an unused subtitle sequence played through `story/scenes/scene.lua`'s talk, a hook on the subtitle slot's `UpdateText` that writes the mod's lines, the reading holds, the fallbacks and the kit version ([Lily's signal](../world/lily-signal-internals.md)) |
| `story/together/snapshot.lua` | `coop story` and `coop-story.txt`: the story lines of the fullest live `SBSaveGame`, written to `StellarCoopStory.txt` part by part, or a list of the objects that may hold them; reads only ([Story dump](story-dump.md)) |
| `fight/bosses/lion_rows.lua` | The rows as `fight/bosses/lion_rows.h` writes them, for the read-back: the lion rows batch (`R.ROWS`), the Gardener's (`R.GARDENER`), the Tendril's (`R.TENDRIL`, with the Shows to build in `R.TENDRIL_SHOWS`), the Shock Bolt's (`R.BOLT`, as `eve/bolt_rows.h` writes them) and the Night Operation shop's (`R.SHOP`, as `online/modes/nightop/shop_rows.h` writes them); written by the rows' generator |
| `eve/chainspin_rows.lua` | EVE's copy of the ChainSpin rows of `fight/bosses/lion_rows.lua` (`R.CHAINSPIN`), where `eve/chainspin.lua` reads the effect's ID; written by the rows' generator, checked by `tests/tools/row_copies_test.py` |
| `world/maps/matrix13/level/boss_rows.lua` | Matrix XIII's copy of the Lion's and the Gardener's rows (`R.ROWS`, `R.GARDENER`) for its title batches; written by the rows' generator, checked by `tests/tools/row_copies_test.py` |
| `story/scenes/lines.lua` | `coop lines`: the timing of four cut scenes' subtitles (each line's start in its level sequence with its `StringTable_Seq` key or its section's number, read offline), their text read from the game when one starts (`TextFromStringTable`, or the sections of Sky Hall's loaded test sequences) and said into the chat's feed at those times; and Quest_Sub_008's unused voice takes, loaded when `enya` starts, played one after another through `SpawnSound2D` (each 1 s after the one before ends, from its SoundWave's `Duration`) with the subtitles the table has for them |
| `eve/glide.lua` | `coop glide`: sets EVE's `bGlide` while Jump is held in the air past the top of her jump, and clears it ([Cut glide](../eve/eve-internals.md#cut-glide)) |
| `eve/emote.lua` | `coop emote`: one of EVE's clips (a looped photo-mode pose, a wave, a clip of the Cut category played once), played by the native part through SB's custom animation call or else as a dynamic montage in `DefaultSlot`, stopped when she moves, jumps or starts a skill ([Emotes](../eve/eve-internals.md#emotes)); also, for `online/lobby/sbo.lua`, the sit loop of a hall lobby seat that SB's chairs leave to the menu key (the fallback to SB's own sit), which `preload` looks up ahead of the sit so the first sit finds the clip in memory |
| `cutmenus/mailbox.lua` | `coop gift`: the inventory read asked of the native part, the game's remove request, the gift file, the gift lines and their answers, the items coming back and the take through the shop's grant, and the cut toast ([Cut mailbox](../cutmenus/menus-internals.md#cut-mailbox)) |
| `eve/wear.lua` | `coop wear`: sets the mesh of EVE's body or hair component (with the hair's animation Blueprint and physics asset) to a cut suit or hair and keeps the game's own look in `coop-wear.txt` to give it back. It puts the worn look on again when the game sets its own |
| `story/scenes/scene.lua` | `coop scene`: two unused rows of the game's theater table pointed at a cut scene's theater and read back, the Emil farewell's take lent to E03, E03's subtitles left in Korean and Japanese (no text registration), the level sequence actor it follows once a second through the engine's class hash (the theater observer, walked for, with no `theater=` field) and the Stop row that ends it; Lily's talks through Quinn's theater, its take lent the same way, or through the rows' level sequence with no theater |
| `core/unreal.lua` | Small helpers over UE4SS objects |
| `core/pak_gate.lua` | Finds a pak of ours (the Matrix XIII test pak, the hall lobby pak) in `SB/Content/Paks` from its `.utoc`, with its `.pak` and `.ucas` beside it, without loading anything |
| `core/keep.lua` | The keep's Lua side: the asset paths modules want, written to `coop-keep.txt`; each kept asset found once with no load or walk and held; off for the Lua load when the native part cannot keep them, so modules load as before |
| `core/line.lua`, `core/player.lua`, `core/actors.lua`, `core/where.lua`, `core/worlds.lua`, `core/row_edit.lua`, `core/picks.lua`, `core/items.lua`, `core/effect.lua` | Helpers cut out of the modules for every module to read: text lines and names, EVE and her controller, the display actors, our EVE's world and place, the story worlds' maps, a table row edited in place and read back, the select widgets' picks, the shop's item grant, the ChainSpin's effect call ([Modules and isolation](#modules-and-isolation)) |

The runtime runs two game-thread loops, which call each module's work. One runs every frame (`main/frame.lua`): the
ghost's build step, `coop_tick`, placing the ghost, the Doro look, the cut model display and free camera, `coop lion`'s,
`coop gardener fight`'s and `coop tendril fight`'s waits and lines, a Doro race (with the incoming lines while one is
armed), the notice line, the previews' follow-ups, the `coop wear` check (once a second), the `coop lines` scene's due
lines, the `coop glide` and `coop emote` checks, the UI's open and close animations, the game's input given back after
the menu or the chat box closes, the controller's events, the row under the mouse (every 100 ms while the menu is open),
and your friend's marker and gauges. The other runs every 250 ms (`main/pass.lua`): link status changes, session start,
notices to show, chat lines in and out, Night Operation's run, the race's session and map checks, the UI's root and its
focus watchdog, the menu's rows and status line, the phone booth scan, the chat's feed, your friend's card, the capture,
the remote table and the day and night cycle's request and sky.

The [co-op line](../players/interface.md#co-op-line) opens at the camp phone booths that the levels place, actors of two
classes: `Env_Camp_TeleportMachine_C` (the booth of every full camp, and Xion's five booths) and
`Env_Camp_TeleportMachine_Standalone_C` (the warp phones). In the Wasteland they stream in and out with distance, so
`online/session/booth.lua` looks for them again. A booth never moves, so each one a scan finds is kept until the map
changes, and a scan runs only where it may find a new one: both classes at once after a map change, then once EVE is 100
m from where the last scan ran, at most every 30 s. Scans run only while the on-screen UI is up, the world shows, the
game is not paused and the menu is closed.

A scan asks the engine for the actors of each class (`GetAllActorsOfClass`, which reads its class hash).
Up to 0.6.0-beta.1 it used `FindAllOf`, which walks every object: 60 to 79 ms on the game thread at each scan, a freeze
every 4 s. The hash route still took 20 to 55 ms a scan in game (59 ms for the first scan on a new map, `UE4SS.log` of
2026-11-12), so a scan every 4 s still gave micro freezes; now none runs while EVE stays within 100 m of the last scan's
spot. The fast route is checked once a Lua load against `FindAllOf` on the player controller, and if this UE4SS cannot
use it, scans walk as before. Each scan also looks up both classes by path, through the engine's name hash (the soft
class path of `KismetSystemLibrary`, `class_at` in `core/unreal.lua`), which loads nothing. UE4SS's `StaticFindObject`,
used before, walks the object array and made each scan 31 to 61 ms in game. The soft path is checked once a Lua load:
the class of EVE's pawn must come back by its own path. If it does not, scans use `StaticFindObject` as before. A scan
that is due still waits while EVE moves faster than 3 m/s (her run is 5 m/s) and runs once she walks or stops. A scan
keeps each booth's `EnvActorName` and position, and no booth is read between scans. A scan that fails adds nothing and
keeps the booths found before it; the next try runs 30 s later, as the spot of a failed scan does not count as scanned.

Each scan is timed: `UE4SS.log` gets `booths: <n> on <map> (<ms> ms)`, with the number of booths found on that map so
far, when the count or the map changes, and `booths: slow scan <ms> ms (<n> found, <route>, <lookup>)` for a scan of 5
ms or more, where `<n>` counts that scan's booths, `<route>` is `class hash` or `walk` for the actor lists and
`<lookup>` is `soft path` or `walk` for the class lookups (`walk (<reason>)` when the soft path check failed). The
lookup route also gets `booths: class lookup route: <lookup>` once it is decided, so a failed check shows on fast scans
too. The menu
key opens the line when the nearest booth is within 3 m of EVE. Nothing in the game changes: the mod edits no table row,
spawns nothing and fires no zone event, and the booth's travel and save stay the game's.

### Files shared by Lua and the native part

Apart from the call to `coop_tick`, Lua and the native part exchange data through small files in the mod folder. Each
file is written in full beside its final name and then renamed over it, so the reader never sees half a file:

- Lua writes `coop-request.txt` (a console request), `coop-session.txt` (a new token per Lua load, so the native part
  drops what an older load published), `coop-components.txt` (EVE's capture), `coop-display.txt` (the ghost it built),
  `coop-state.txt` (whether a save is loaded or the title screen is shown, the send rate, and the synced photo mode's
  state and settings) and `coop-night.txt` (our side of a Night Operation run, which the native part takes at its next
  pass and sends to the friend; a newer line replaces one not taken yet).
- The native part writes `coop-status.txt` (the state Lua and `coop status` read), `coop-remote.txt` (the remote
  table), `coop-cns.txt` (the assets your CNS packs declare, once at start), `coop-shared-assets.txt` (the assets of
  the mods you and your friend both have in one version, when that list changes), `coop-link.log` and
  `coop-report.txt`.
- The chat has two files that exist for a moment only. Lua writes a typed line into `coop-say.txt` once the native
  part has taken the previous one, and the native part takes and deletes it at its next pass (every 5 to 50 ms). The
  native part writes your friend's lines into `coop-chat.txt` (`in <SteamID> <text>`, or `fail` for a line of yours
  that could not be sent) once Lua has taken the previous file, and Lua reads and deletes it every 250 ms. Both files
  are deleted when a session ends, when the native part starts and when the game exits. Chat text is written nowhere
  else. A crash dump (`Saved/Crashes`) holds the game's memory, so it may hold lines of the session.
- A Doro race uses the same pattern. Lua queues its race lines and writes all those waiting into `coop-race.txt` once
  the native part has taken the previous file, and the native part takes it at its next pass and sends each line in
  order. Your friend's race lines come in `coop-chat.txt` as `race <text>`, beside the chat lines, and Lua reads that
  file every frame while a race is armed. `coop-race.txt` is deleted with the chat files.
- `coop gift` sends its lines as requests (`gift <payload>` in `coop-request.txt`), and asks the inventory read the
  same way (`items ...`, answered in `coop-status.txt`). Your friend's gift lines, and a gift of yours that could not
  go, come in `coop-chat.txt` as `gift <payload>` ([Cut mailbox](../cutmenus/menus-internals.md#cut-mailbox)).
- Another member's camp rest comes in `coop-chat.txt` as `rest <zone> <SteamID>`. `main/input.lua` hands it to the
  group module ([Rests between members](../online/group-internals.md#rests-between-members)).
- The SBO lobby's screens (the lobby menu, its settings and the Leave question) hide Stellar Blade's HUD. Every 250 ms
  `online/lobby/wiring.lua` asks `hud hide on` when one of them has opened and `hud hide off` when the last one has
  closed, and `hud hide off` once after each Lua load. On the game thread the native part passes its own key,
  `SBOLobby`, to the game's keyed HUD request (`FUN_141fca0f0` on build 26123051). The game hides the HUD while any key
  is in its set, so our key and the keys of photo mode and the game's menus never undo each other. The DLL remembers
  whether our key is in: an `off` with nothing hidden calls nothing, and `coop off` takes the key out. `coop-link.log`
  has `hud: SB's HUD hidden for the lobby (key SBOLobby)` and `hud: SB's HUD shown again`.
- The day and night cycle asks `sky off`, `sky cycle`, `sky hour` or `sky hold` in `coop-request.txt` only when its
  decision changes. It reads its state, hour and sun from the `sky=` line of `coop-status.txt`
  ([Day and night](../world/daynight-internals.md#the-request-and-the-status-line)).
- Each warp into an SBO lobby (the entry, a guest's warp to her host's hall, a Private match on another hall, `coop sbo
  back`) arms the arrival's hold (`online/lobby/arrival.lua`). Stellar Blade hides its travel screen at the end of its
  own arrival flow and has no setting that keeps it up, so the hold uses the game's second loading screen: at the 250 ms
  pass after the new world's `PlayerController:ClientRestart` (a UE4SS hook), Lua calls
  `USBBlueprintLibrary::LoadingScreenFadeAuto` (a 10 s lifetime, 0.5 s fades, tag 5) and collapses the UI root, whose
  z-order of 100 would draw over the black's 10. Under it the lobby gets ready: EVE on her spot, a hall's chairs spawned
  on a 100 ms budget and their bind check, the UI's whole look (warmed on a 100 ms budget too) and the menu camera. From
  the arrival on, Lua also asks `hud hide on` under the black, so SB's HUD is already hidden when the black fades out.
  Then Lua asks `loading lift`, shows the UI root and opens the lobby menu in the same pass. On the game thread the
  native part sets the lifetime of each tag-5 entry in the game's UI manager to 0 (`online/lobby/loading.h`), and the
  game's loading controller runs its own end fade at its next tick. Lua lifts the hold 8 s after the black went up
  whatever is missing, with the missing items in the log; the game ends the black 10 s after its fade-in even with no
  Lua. A Lua reload during the hold loses track of the black, so the new Lua load asks `loading lift` once at its first
  pass in the lobby world, unless that pass or an earlier one of the same load put up its own black; with no black up
  the lift ends nothing, since only this mod puts up tag-5 entries. `coop-link.log` has `loading lift: <n> of SB's black
  screens set to end`; the Lua lines start with `arrival:`.
- The recruiter's lines go as one request too (`guardtext`, the culture and his seven lines, each after a tab),
  answered by the `guardtext=` line of `coop-status.txt`.
- The [bike](../vehicles/bike-internals.md)'s asks go as requests (`bike load <clip>`, `bike free`, `bike gate on`,
  `bike gate off`, `anim play <id> <clip> ride`), answered by the `bike=`, `bike_gate=` and `anim=` words of the engine
  line in `coop-status.txt`. They stay on your PC. Her parked bike's line goes through `coop-parked.txt`, which the
  native part takes and sends to each member as a `bike` message (see [The bike
  line](../online/steam-link-internals.md#the-bike-line)). The members' lines come back as the `bike_of=` lines of
  `coop-status.txt`.
- The keep's list goes through `coop-keep.txt`: the object paths of the assets the mod keeps in memory, one a line,
  the whole list each time it grows. The native part takes the file at every pass and asks the game's own async loader
  for the new paths. The `keep=<asked> <settled> <in>` word of the engine line in `coop-status.txt` answers, or
  `keep=fault`.
- The `theater=` word of the engine line in `coop-status.txt` tells Lua what SB's theater plays, read on the game
  thread every 100 ms: `none`, the sequence's name, `-` while its first take loads or its name is not read, or `fault`.
  No request asks for it.
- Two files are Lua's alone, for the [crash sentinel](../online/partner-internals.md#cns-guard-and-crash-sentinel):
  `coop-cns-call.txt`, written in place with no temporary file to keep each write to one, and `coop-cns-aside.txt`, the
  set-aside list.

The full list is in [Settings](../players/settings.md#files-in-the-mod-folder).

## Modules and isolation

The Lua side is cut into 20 modules, one folder each ([Structure](structure.md#modules) lists them). A module
that fails to load is off until the mod reloads; the other modules stay on.

### The manifest

Each module's `wiring.lua` returns its manifest, here `online/modes/race/wiring.lua`'s, shortened:

```lua
return {
uses={'online.partner','online.modes.nightop','vehicles.bike'}, -- the modules it reads later, never while it loads
exports={'doro','drive','race'},                                 -- every M field its new and its build steps set
new=function(M)                                                  -- its share of the startup; returns its coop words
    M.doro=require('online.modes.race.doro').new({...})
    ...
    return require('online.modes.race.commands').new({...})
end,
build={hud=function(M,Ui) M.race.hud({kit=M.kit,theme=Ui.THEME,settings=M.settings}) end},
}
```

No manifest has a `needs` field: no module needs another. `main.lua`'s `MODULES` lists the 19 in the order their
constructors run, the order they had before the modules were cut apart, so every constructor, native request and hook
runs in the same order. No module reads another module's export while it loads, so the order is not a dependency.

### Loading

`main/loader.lua` first requires every `wiring.lua` and sets each export of every manifest to the stub. For a
`wiring.lua` that does not load, it reads the exports from the file's `exports={...}` text, so other modules' late
reads still find a stub. Then, in list order, it runs each `new(M)` under `xpcall`. On success each export is what
`new` left in `M`, `nil` included: without the Steam link some are nil by design. The words `new` returns join
`M.commands`, where a word defined twice raises.

A stub is a table whose every field is a function that does nothing and returns nothing. An export is a function or a
table of functions. A plain value that two files read (a clock, a flag) belongs to the runtime, in `main/base.lua`
(`M.chat_clock`, `M.at_title` and the rest), so no module that goes off can turn it into a stub.

### When a module fails

A `require` of its `wiring.lua`, its `new` or one of its build steps that raises turns that module off alone until the
mod reloads:

- its exports go back to the stub and its words leave `M.commands`;
- `UE4SS.log` gets `[StellarCoop] <module>: off until the mod reloads: <error>`, then the error's traceback;
- with the Steam link, the 250 ms loop says one notice in the menu's language once the UI is ready or a world is
  loaded: `T.<culture>.module_off` with the module's name from `T.<culture>.modules`, in English
  `The bike is off until the mod reloads: it failed to load. UE4SS.log says why.`;
- `M.off_modules` holds its name and the error.

No other module is touched. A hook that a wiring registers with UE4SS outlives an off module, so its callback starts
with `if M.off_modules['<module>'] then return end` (the lobby's `ClientRestart` hook).

### Late reads

A module reads another module's state only after loading, through that module's exports, in one of three forms. Each
reader lists the module it reads in its `uses`.

- A call through `M` at call time: `night=function() return M.night.running() end`. While Night Operation is off it
  gives nil: no run.
- A view, `require('main.loader').view(M,'puppet')`, for a constructor that keeps an object: each field read reads
  `M.puppet` at that moment, so an off module answers as its stub.
- A getter, `require('main.loader').get(M,'fight.bosses','lion')`, for code that tests whether the object is there: it
  returns the export, or nil while the module is off.

Most late reads of an off module give a state that already exists: no run, no ghost, not riding. Where nil would make
the reader raise or log `nil`, the reader's wiring returns its own refusal while the module it reads is off. Night
Operation's cut items, for one, answer `coop lion is off until the mod reloads`. The capture goes further, as a user
decision rests on it: while the bike module is off, it leaves out the hidden bike part an earlier Lua load left on EVE
through its own copy, `online/partner/bike_part.lua`, so the ghost never shows a bike while EVE does not ride.

### Copies

Feature code that two modules used is copied into each, with its tests. Each copy's first line after the license says
whose copy it is; from then on each module fixes its own.

| Copy | Of | For |
| --- | --- | --- |
| `vehicles/bike/drive.lua`, `vehicles/bike/drive_model.lua` | `online/modes/race/drive.lua`, `online/modes/race/drive_model.lua` | The bike's riding |
| `online/partner/doro_pick.lua` | `online/modes/race/doro.lua`'s clip pick and tilt | The ghost's Doro mode |
| `fight/bosses/enemy.lua` | `core/enemy.lua` | The cut monsters' flow; Matrix XIII's and the hall lobbies' batches keep `core/enemy.lua` |
| `online/partner/bike_part.lua` | `vehicles/bike/ride.lua`'s `find_part` | The capture while the bike module is off |

`world/maps/matrix13/level/travel.lua` also asks the Lion's and the Gardener's rows itself, where it read them from
`fight/bosses/lion.lua` and `fight/bosses/gardener.lua`.

While the races and the bike shared one drive, the drive gave four cross-checks. Each is now a late read of
`M.riding()` or the races' drive: no race start, drive probe or drive off while EVE rides; the guest taken off the
bike at a track line; no ride while the races' drive runs. Two pieces of state stay apart. `coop race drive feed`
sets the races' drive only (the bike's stays `impulse`). A failed drift-key read latches in each copy on its own. Both
copies keep EVE's movement values in `coop-drive.txt`: the races' restore runs first in the frame loop, the bike's
after it. With both modules on, the first puts the values back and clears the file; with one off, the other does it.

Code that only reads the game, a row batch or a text is no feature code. It moved to `core/` (`core/actors.lua`,
`core/line.lua`, `core/player.lua` and the rest), `ui/kit/hud_parts.lua` and `ui/text/culture.lua`, where every module
reads it.

### Build steps

A module's screens and HUDs are kit groups. The kit draws its groups in the order they are built: the feed and the HUDs
first, the menu over them, the questions over all. `main/ui.lua` builds the kit, the guide and the menu, with each
module's build steps between them at their place in that order
(`require('main.loader').build(M,'online.session','box',Ui)`). A build step of an off module is skipped. One that
raises turns its module off, with its later steps skipped.

### The loops

`main/frame.lua` and `main/pass.lua` reach the modules only through their exports, each call under `guarded()`: an
error that escapes it is logged once a Lua load; the modules after it still run in that pass
([Safety design](safety.md#safety-design)).

### Native parts

The DLL has no load isolation: `glue/tick.cpp` is one translation unit that includes every part. Each part's game calls
run under its own SEH latch (64 `__try` blocks, 36 `*_faulted` flags): a fault there turns that feature off for the run.
A part may read what the parts before it define, so `tick.cpp` includes them in a declared order. Comments beside the
includes name the parts one reads or must come before (`world/daynight/sky_game.inc` comes after
`glue/tick/freeze_game_shared.inc`, whose controller reach it uses). What another module's part reads of a part is in
`glue/tick/<part>_shared.inc`, included right before that part. Each module's table rows are a header of its own that
`tick.cpp` includes right after `rows/rows.h` ([Row tables](structure.md#row-tables)). The headers that more than one
module reads are in `game/`. No module's part, header or test includes another module's header or uses a name another
module's part defines.

### The checks

- `tests/tools/modules_test.py` fails on a `needs` key; on a module's file or test that requires, fakes or patches a
  file of another module; on a late read missing from `uses`; on an export that two modules set; on a build step that
  `main/ui.lua` does not build; on a hook callback without its `M.off_modules` check; on a native file of a module that
  reads another module's header or part; on a language table whose `modules` differs from `MODULES`.
- Each module's `tests/lua/<module>/off_test.lua` makes its require, the start and the end of its `new` and each of
  its build steps raise in turn. Each time the mod must load with every other module on and run its frames, passes,
  binds, hooks, `coop ui reset` and `coop off` with no other module's off line and no `OK: nil` in the log.
- `tests/lua/main/loader_test.lua` tests the loader alone.

[Tests](tests.md#lua-tests) says more about each.

## The co-op UI's input

The co-op menu, the guide, the co-op saves' question, the host's question, the chat box and the code box take the game's
input while they are open. The kit (`ui/kit/kit.lua`) calls `SetInputMode_UIOnlyEx` with its root focused, or with the
box's text field for the chat box and the code box. The game's viewport then ignores every key and controller button, so
EVE stands still. The menu's keys are UE4SS key binds, which read the keyboard and the mouse buttons whatever has the
focus. When the UI closes, the kit gives the input back 150 ms later, so the key that closed it never reaches the game
(Esc would open the pause menu): `SetInputMode_GameOnly` in a world, and at the title `SetInputMode_GameAndUIEx` with no
mouse capture, so the title menu keeps its cursor. The game reads the keys of its own screens as player controller
actions (`UI_DPad_*`, `UI_FaceButton_*` and `UI_GameMenu` in its `DefaultInput.ini`), which need the viewport's input,
so its screens work again after the give-back.

### Controller

UE4SS cannot bind a controller button, and UIOnly makes the game ignore the controller, so the native part reads it
itself: through the game's own controller events when it can, else through XInput, a polling API that takes nothing
from the game.

- Slate's message handler (the Slate application at `0x146faa4d0`, its handler at `+0x118` with the vtable
  `0x145fe5430`) has three controller slots: analog `+0x88`, button pressed `+0x90` and released `+0x98`. The engine's
  XInput poll and SB's DualSense module both call them, so they see every controller the game reads. Once a run the
  worker finds the twelve key names `ui/pad.h`'s `PadKeys` reads (`Gamepad_DPad_Up` to `Gamepad_LeftY`) with FName's
  find, which never makes a name, checks the handler's vtable, then swaps the three slots by compare-and-swap, all or
  none. Each hook records the key into `PadKeys` (relaxed atomics) and runs the game's function with the same
  arguments; it never drops or changes an event. `PadKeys` keeps each controller's held buttons in XInput's bit layout
  and its left stick, ids 0 to 7; a read gives the held buttons of every controller ORed with the presses since the
  last read, so a press and its release inside one 8 ms poll still count. A repeat is no press: `ui/pad.h` makes its
  own. A missing name, another vtable or a slot holding anything else leaves XInput as the source, with one log line.
  coop off gives the slots back by compare-and-swap from our hooks only; XInput is the source again.
- The worker loads `xinput1_4.dll`, else `xinput9_1_0.dll`, with `LoadLibraryExW(..., LOAD_LIBRARY_SEARCH_SYSTEM32)`,
  and takes `XInputGetState` from it. The game's folder can hold another tool's `xinput1_3.dll` proxy, which is never
  loaded.
- `coop_pad` runs on the game thread. At most once per 8 ms it reads `PadKeys` while the hooks are the source, else
  XInput's slots 0 to 3: their buttons ORed and the first connected controller's left stick. A slot with no controller
  is asked again only after 2 s and only one such slot per read, since asking an empty slot can cost milliseconds.
  While another process's window is in front nothing is read and the held state counts as released: XInput answers
  whatever window has the focus. Slate may never deliver the release of a button held across an alt-tab, so `PadKeys`
  forgets its holds then.
- `ui/pad.h` turns the reads into events: up, down, left and right from the D-pad or the left stick (pressed at 50 % of
  its range, released under 30 %), a D-pad diagonal read as up or down and the stick along its main axis (up or down
  when both are equal; an axis already pressed stays until the other is more than 10 % larger, so a stick held near 45
  degrees does not switch at each read), up and down repeating after 400 ms then every 120 ms, A for select, B for back,
  View held 1000 ms for the menu, once a hold, LB and RB for the tab to the left and right and Y for the Sessions
  screen's Refresh, once a press. D-pad Right held 1000 ms gives the [bike](../vehicles/bike-internals.md)'s event, once
  a hold, after its right. A ring of 8 holds them; a full ring drops the newest.
- The DLL links no Lua, so each event travels as a result count. Lua calls
  `select('#', native_pad(0,0,0,0,0,0,0,0,0,0,0))`: `coop_pad`, called as a Lua C function, returns n. Lua hands back
  the top n of the 11 arguments on its stack. n is the event, 1 to 11, or 0 when the ring is empty. `main/frame.lua`
  takes at most 8 events a frame and `main/input.lua` routes them as the keys route theirs: the join popups get every
  word first while one is open, the SBO lobby's screens get the six navigation words while one is open and View closes
  it to the waiting room, the Sessions screen and the Create a session screen get every word while one is open (Y is the
  Sessions screen's Refresh) and View closes it, the open menu gets the six navigation words and View closes it, the
  co-op saves' question gets up, down, select and back (the guide gets them first while it is open), the chat box and
  the code box get back only (it closes them). With nothing open, in a world with the HUD shown, View opens the lobby
  menu in the SBO lobby's world and the co-op menu elsewhere, through the same path as `menu_key`. LB and RB change the
  tab of the lobby's settings screen or of the Sessions screen while one is open and do nothing anywhere else. The
  bike's event goes the path of `bike_key` in a world with the HUD shown while none of these screens is open and the
  game is neither paused nor showing one of its screens; it does nothing otherwise (the log says why).
- The worker logs each change of the connected slots (`pad: XInput pads connected: <slots>`, `pad: no XInput pad`).

### Mouse

While the menu or the guide holds the input, the kit sets the player controller's `bShowMouseCursor` after the input
mode and keeps the value it found. That value goes back when the input goes back, when a text box takes the input, at
`coop ui reset` and at `coop off`. A Ctrl+R with the menu or the guide open leaves ` cursor` beside ` input` in
`coop-ui.txt` (` cursor shown` when the cursor was already shown, as on the title screen), and the next Lua load puts
that value back as it gives the input back. `coop-sbo.txt` holds the path of the SBO lobby's menu camera, so the next
Lua load removes that camera before it makes its own. The check that keeps the menu closed while one of the game's
screens shows the cursor ignores the cursor while it is the menu's or the guide's. Every 100 ms the menu asks its 15
drawn rows whether the mouse is over them (`IsHovered`), and a row the mouse moved onto takes the focus. The
`LEFT_MOUSE_BUTTON` bind selects the row under the mouse and `RIGHT_MOUSE_BUTTON` goes back. Slate gives a click that
none of the mod's widgets takes to the game's viewport, with the keyboard focus, so while the UI holds the input either
button has the kit focus its root (or the box's field) again 50 ms later.

### Focus watchdog

The kit makes its root focusable (`bIsFocusable`) before it adds it to the viewport, so the input mode focuses the root
itself. Every 250 ms while the UI holds the input, it reads `HasAnyUserFocus` or `HasFocusedDescendants` on the root.
The watchdog arms at the first yes since the input was taken; armed, 1 s of no fires it once. `main/pass.lua` then runs
the same function as `coop ui reset`: the menu, the chat box and the code box closed, an open host's question denied
(which fails closed), the co-op saves' question closed as Decide later (a copy pass already asked for keeps running and
is followed on, where `coop ui reset` withdraws it), the input given back at once and the menu's cursor put back. One
log line names the holder; nothing shows on screen. Just before it, a second line lists the class of each top-level
`UserWidget` other than the root that holds the focus (`none` when the game's viewport, a Slate-only widget or another
window has it), whether the game is paused or shows its own cursor, and the seconds since the last mouse button; a
lookup that raises logs `focus not read (<why>)` instead. The worker logs each change of the window in front to
`coop-link.log` (`window: the game is in front`, `window: another window is in front`). A root that never had the focus
2 s after a take leaves the watchdog unarmed, with one log line a Lua load. The Steam overlay should keep Slate's focus
where it was and then not fire the watchdog (not tested in game yet). The game, another mod, or a middle or side mouse
button moving the focus does.

### Line breaks

Every text the mod wraps goes through `online/session/chat.lua`'s `wrap`: the chat feed and history, the notice line
above EVE and the co-op saves' question. The kit's UMG texts never wrap on their own. A row breaks at the last space
within reach, else between two characters (Chinese, Japanese and Thai put no space between words), and a mark that takes
no column (Thai and Arabic vowel and tone marks) stays with the letter before it. Thai writes the vowels U+0E40 to
U+0E44 (เ แ โ ใ ไ) before the consonant they follow in speech, so a row never ends on one: between two characters the
cut moves back before such a vowel, unless the row would be left empty.

## Loopback, record and replay

These solo tools run the whole pipeline on one PC, so most of the mod can be tested without a second player.

- The loopback sends EVE's capture as the table, then her poses, through an in-process delay line in place of Steam. It
  applies the one-way delay you give, plus or minus the jitter, and loses each 1200-byte segment of a pose at the rate
  you give (Steam's relay splits a message the same way, and one lost segment loses the pose). The line keeps order,
  like a single relay route. What comes back is handled exactly like a friend's data: the table is checked and the ghost
  built from it, and the poses are decoded and drawn on the playback clock. Because the ghost is yours, it walks 2 m to
  your right. The side is taken when the ghost shows and kept while it shows: taken at each pose, your turns would
  swing the ghost around you and throw its cloth sideways.
- A recording keeps what is sent (the table and the poses, as the exact wire bytes) in memory for up to 120 s or 25 MiB,
  and writes it to `coop-record.bin` when it stops. The file holds `SBR` and the protocol, then entries of a kind (`T` a
  table, `P` a keyframe, `D` a delta, `E` a same-place enemies' `SBE` or `S` a show line), a size and the bytes.
  `SBE` messages and show lines come after the first pose and are re-stamped with the poses on replay. A show line over
  493 bytes is not recorded: its new time can be up to 19 digits longer, and past 512 bytes the line would lose its
  hit context.
- A replay reads and checks the whole file before anything plays (the tests fuzz the reader), then plays it in a loop as
  the remote side, each pose re-stamped as if sent now. A file made under another protocol is refused.

The commands are in [usage.md](../usage.md#solo-testing-loopback-record-replay).
