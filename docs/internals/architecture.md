# Architecture

The other pages in `docs/internals/` go feature by feature, and [How it works](../how-it-works.md) lists them. The
repository layout is in [Building](../building.md#repository-layout).

## Lua and native parts

Stellar Blade Online has two parts, both in the mod folder `Mods/StellarCoop/`:

- The Lua part (`Scripts/*.lua`), run by UE4SS on the game thread. It uses UE4SS's object API to read what EVE is made
  of, build the ghost's actor and place it, draw the co-op menu, the chat and your friend's card, marker and arrow,
  show notices, and handle the console and the keys.
- The native part (`StellarCoop.dll`), loaded by the Lua script with `package.loadlib`. It has three entry points:
  - a worker thread, started when Windows loads the DLL. It makes every Steam call, reads and writes the files shared
    with Lua, sends and receives tables and poses, and writes the logs.
  - `coop_tick`, an exported function that the Lua loop calls once per frame on the game thread. It reads and encodes
    EVE's pose from engine memory, decodes the poses that came back, and writes the ghost's bones.
  - `coop_pad`, an exported function that the Lua loop calls each frame for the controller's events (see
    [Controller](#controller)).

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
| `main.lua` | Entry point: loads the DLL, reads the settings, registers the `coop` command and the keys, runs the loops |
| `commands/session.lua` | The session's `coop` commands: `host`, `invite`, `join`, `leave`, `status`, `report`, `copy`, `mark`, `allow`, `deny`, `remove`, `revive test`, `travel` and `saves` |
| `commands/partner.lua` | The ghost's `coop` commands: `puppet`, `basesuit`, `where`, `look`, `loopback`, `record`, `replay` and `freeze` |
| `commands/nightop.lua` | `coop no`, `coop nightop`, `coop challenge` and `coop recruiter`, with their co-op save check |
| `commands/race.lua` | `coop race`: the Doro look and probe, and the co-op save check before `race/run.lua`'s command |
| `commands/fight.lua` | `coop fight` (its pilot and spawn probe included) and `coop quests`: their lines for the native part |
| `commands/cut.lua` | `coop leviathan` and the other viewer commands (`gardener`, `tendril`, `mann`, `nier`, `orcal`, `enya`), with the co-op save check before `show` and before `cam` turns the camera on; `coop lion`, with the co-op save check before the words that spawn; `coop gardener fight`, handed to `cut/gardener.lua` with the co-op save check and the viewer's display put away before the words that spawn; `coop tendril fight`, handed to `cut/tendril.lua` the same way; `coop wear`; `coop scene`, with the co-op save check before a scene's name (`coop scene lily` handed to `matrix13/quest/on_time.lua`'s talk); `coop lines`; `coop emote`; `coop fly`, `coop slowmo` and `coop glide`, with the co-op save check before `on`; `coop gift`, with the co-op save check before every word |
| `commands/guide.lua` | `coop guide`, which opens the guide |
| `core/link.lua` | The Lua side of the shared files, `coop-settings.txt`, the status key's summary |
| `partner/capture.lua` | EVE's capture: what a ghost of her is made of (read only) |
| `partner/puppet.lua` | The ghost: builds it from a table, places it, its name tag, effects, its Doro mode in a race, `coop where` |
| `ui/notice.lua` | The line of notices above your EVE, used while the on-screen UI is not up |
| `session/chat.lua` | The session chat: its history (memory only), the feed of chat lines and notices, and the text box |
| `session/join.lua` | The code box and the host's question about a player who is not her Steam friend |
| `partner/hud.lua` | Your friend's card, marker and off-screen arrow, and the maths that places them |
| `session/booth.lua` | The camp phone booths near EVE, for the co-op line |
| `ui/menu.lua` | The co-op menu: draws its pages, takes its keys, runs its rows as `coop` commands, writes and applies settings |
| `ui/model.lua` | The menu's rows and settings, with no engine call |
| `ui/guide.lua` | The first-launch guide: its pages, keys, mouse and pad, `coop-guide.txt`, and the Mother Sphere art imported from `Assets/MotherSphere.png` at run time (`ImportFileAsTexture2D`) |
| `ui/guide_text.lua` | The guide's words and its menu row's, in the same languages as `ui/text.lua` |
| `ui/text.lua` | The words of the menu, the chat, the partner HUD, the co-op saves, the join codes, the status line, the Doro race's HUD and the notices written in Lua, in the game's 23 text languages |
| `ui/kit.lua` | The UI kit (runtime UMG widgets in the game's look) that draws the menu, the chat and the partner HUD |
| `core/keybind.lua` | The key settings' grammar and their clash check |
| `core/settings_file.lua` | Rewrites one line of `coop-settings.txt` and keeps the rest of the file |
| `core/ue4ss_settings.lua` | Checks `HookBeginPlay` and `bUseUObjectArrayCache` in `UE4SS-settings.ini` (read only) |
| `nightop/probe.lua` | The `coop no` probe, and the heal that a Night Operation run or a challenge fires |
| `nightop/waves.lua` | The run's waves, keys, score, timers and states, read from a definition, alone or for two players, the pairing of new bodies with their spawn spots, a spot moved onto the navmesh through navmesh calls it is given (`W.settle`), and the night line's two formats, with no engine call |
| `nightop/run.lua` | The `coop nightop` run and the `coop challenge` runs: start checks, the host's ask and the guest's answer, spawns and the navmesh calls that settle their spots, the monsters it tracks, a co-op run's down and revive, the night line, its card and result panel |
| `nightop/shop.lua` | Night Operation's reward shop: the points file, `coop nightop shop` and `buy`, and its one item request |
| `nightop/challenges.lua` | The challenges' waves and rules, the `coop challenge` list and the best runs in `coop-records.txt`, with no engine call |
| `nightop/board.lua` | The Shooting Range's score on the cut test widget `WB_ShootingTrainingTest`, beside the run's card |
| `nightop/recruiter.lua` | The `coop recruiter` preview |
| `nightop/recruiter_text.lua` | The recruiter's lines in the game's 23 languages (not shown: no text registration), and `culture()`, the game language's culture for the other text modules |
| `race/doro.lua` | The display Doro (a plain actor with Doro's mesh, animated by the engine's single-node animation), the Doro look on your EVE, and `coop race probe doro` |
| `race/model.lua` | Doro races with no engine call: the track file, the rules, the start slots, the host's and the guest's race over the race lines, and the ranking |
| `race/run.lua` | Doro races in game: recording a track, the race run from EVE's feet, its HUD, its Doros and its notices |
| `cut/leviathan.lua` | `coop leviathan` and the other viewer commands: one table of seven cut models (Naytibas 10, 1 and 6, the early Mann, the NieR machines, Orcal's and Enya's prototypes: their meshes, animations, default distance, height and scale, skins) and one viewer for them. It reads a creature's assets and CharacterTable rows, shows one of its meshes playing its animations on a display like the Doro's (one creature at a time) and flies a free camera to film it |
| `cut/enemy.lua` | The flow `coop lion`, `coop gardener fight` and `coop tendril fight` share, each from its own spec: a batch's rows asked of the native part and read back, the spawn, the entrance on a display copy, the material and the boss bar's name, the lines that follow the body ([The cut Lion](cut-enemies.md#the-cut-lion)); `coop mxiii` uses its rows part |
| `cut/lion.lua` | `coop lion`: the Lion's spec for `cut/enemy.lua` and its own parts (the anim instance repair, `unfreeze`, `brain`, `control`); `Lion.rows`, the lion rows batch for the shop's stimpacks and `coop chainspin`, or the bolt rows batch for the shop's Shock Bolt ([The cut Shock Bolt](night-operation-shop.md#the-cut-shock-bolt)) |
| `cut/gardener.lua` | `coop gardener fight`: the Gardener's spec for `cut/enemy.lua` ([The cut Gardener](cut-enemies.md#the-cut-gardener)) |
| `cut/tendril.lua` | `coop tendril fight`: the Tendril's spec for `cut/enemy.lua` and the Shows of its clips, built in memory ([The cut Tendril](cut-enemies.md#the-cut-tendril)) |
| `matrix13/world/travel.lua` | `coop mxiii [30\|leave\|boss]`: the test pak's check (v1 to v4, the `.ucas` read window by window through the `.utoc`'s block table), Matrix XIII's camp batch through `cut/enemy.lua`'s rows part, then the follow's camp travel to `DLC02_00_Camp_00` on v4 (`DLC02_10_Camp_01` on older paks), or with 30 to `DLC02_30_Camp_01` on v3 or later; at the title its four batches and the Lion's and the Gardener's ([Matrix XIII: how it works](matrix-xiii.md)) |
| `matrix13/world/rows.lua` | Matrix XIII's rows as `lion/mxiii_rows.h` writes them, the ladders, ledges and ropes, the boxes and barrels, the boss points and `coop mxiii warp`'s points, written by `tools/mxiii_rows.py` ([Matrix XIII's world rows](matrix-xiii.md#matrix-xiiis-world-rows)) |
| `matrix13/world/mila.lua` | Mila's body, a display only (`race/doro.lua`): Kara's mesh in the sitting clip at the cooked markers, placed by `zone_talks.lua` after scenes 4E and 4N ([Lily's signal](lily-signal.md)) |
| `matrix13/world/breakables.lua` | In world 2800: the 317 boxes and barrels spawned at run time in place of the cooked proxies, which it hides ([Matrix XIII's world rows](matrix-xiii.md#matrix-xiiis-world-rows)) |
| `matrix13/world/move.lua`, `matrix13/world/boss.lua`, `matrix13/world/fans.lua` | In world 2800: the ladders, ledges and ropes spawned at run time, the fixes on the Lion and Gardener the game spawns from their rows, with `coop mxiii boss` as the key-0 fallback, and the fan rotors held still until their levers read On ([Matrix XIII's world rows](matrix-xiii.md#matrix-xiiis-world-rows)) |
| `matrix13/quest/on_time.lua`, `matrix13/quest/text.lua`, `matrix13/culture.lua` | Lily's signal: the signal rows asked and read back, the words written, the prologue's acquire, her choice list's swap asked on and off with its two labels, the picks, the talks, the quests' asks and `coop mxiii`'s travel, the M01 fallback, the drive room check, and `coop lily signal\|talk\|hold` ([Lily's signal](lily-signal.md)); `culture.lua` maps the game's culture to `fr` or `en` for the words and the talks |
| `matrix13/talks/prologue.lua`, `arrival.lua`, `finale.lua`, `zone1.lua` to `zone4.lua` | The talks' lines, one module per talk and one per zone (1A to 1E, 2A to 2G, 3A to 3K, 4A to 4N), each line its speaker, English and French |
| `matrix13/quest/zone_talks.lua` | The zone talks in game: a trigger for each of the 36 scenes, the order rules, the fight gate, one file per co-op slot for the played scenes ([Lily's signal](lily-signal.md)) |
| `story/subtitles.lua` | Lily's talks: an unused subtitle sequence played through `cut/scene.lua`'s talk, a hook on the subtitle slot's `UpdateText` that writes the mod's lines, the reading holds, the fallbacks and the kit version ([Lily's signal](lily-signal.md)) |
| `cut/lion_rows.lua` | The rows as `lion/rows.h` writes them, for the read-back: the lion rows batch (`R.ROWS`), the Gardener's (`R.GARDENER`), the Tendril's (`R.TENDRIL`, with the Shows to build in `R.TENDRIL_SHOWS`) and the Shock Bolt's (`R.BOLT`); written by the rows' generator |
| `cut/lines.lua` | `coop lines`: the timing of four cut scenes' subtitles (each line's start in its level sequence with its `StringTable_Seq` key or its section's number, read offline), their text read from the game when one starts (`TextFromStringTable`, or the sections of Sky Hall's loaded test sequences) and said into the chat's feed at those times; and Quest_Sub_008's unused voice takes, loaded when `enya` starts, played one after another through `SpawnSound2D` (each 1 s after the one before ends, from its SoundWave's `Duration`) with the subtitles the table has for them |
| `cut/glide.lua` | `coop glide`: sets EVE's `bGlide` while Jump is held in the air past the top of her jump, and clears it ([Cut glide](cut-eve.md#cut-glide)) |
| `cut/emote.lua` | `coop emote`: one of EVE's clips (a looped photo-mode pose, a wave, a clip of the Cut category played once), played by the native part through SB's custom animation call or else as a dynamic montage in `DefaultSlot`, stopped when she moves, jumps or starts a skill ([Emotes](cut-eve.md#emotes)) |
| `cut/mailbox.lua` | `coop gift`: the inventory read asked of the native part, the game's remove request, the gift file, the gift lines and their answers, the items coming back and the take through the shop's grant, and the cut toast ([Cut mailbox](cut-menus.md#cut-mailbox)) |
| `cut/wear.lua` | `coop wear`: sets the mesh of EVE's body or hair component (with the hair's animation Blueprint and physics asset) to a cut suit or hair and keeps the game's own look in `coop-wear.txt` to give it back. It puts the worn look on again when the game sets its own |
| `cut/scene.lua` | `coop scene`: two unused rows of the game's theater table pointed at a cut scene's theater and read back, the Emil farewell's take lent to E03, E03's subtitles left in Korean and Japanese (no text registration), the theater observer it follows once a second and the Stop row that ends it; Lily's talks through Quinn's theater, its take lent the same way, or through the rows' level sequence with no theater |
| `core/unreal.lua` | Small helpers over UE4SS objects |

`main.lua` runs two game-thread loops. One runs every frame: the ghost's build step, `coop_tick`, placing the ghost, the
Doro look, the cut model display and free camera, `coop lion`'s, `coop gardener fight`'s and `coop tendril fight`'s
waits and lines, a Doro race (with the incoming lines while one is armed), the notice line, the previews' follow-ups,
the `coop wear` check (once a second), the `coop lines` scene's due lines, the `coop glide` and `coop emote` checks,
the UI's open and close animations, the game's input given back after the menu or the chat box closes, the
controller's events, the row under the mouse (every 100 ms while the menu is open), and your friend's marker and
gauges. The other runs every 250 ms: link status changes, session start, notices to show, chat lines in and out, Night
Operation's run, the race's session and map checks, the UI's root and its focus watchdog, the menu's rows and status
line, the phone booth scan, the chat's feed, your friend's card, the capture and the remote table.

The [co-op line](../interface.md#co-op-line) opens at the camp phone booths that the levels place, actors of two classes:
`Env_Camp_TeleportMachine_C` (the booth of every full camp, and Xion's five booths) and
`Env_Camp_TeleportMachine_Standalone_C` (the warp phones). In the Wasteland they stream in and out with distance, so
`session/booth.lua` looks for them again: both classes at once after a map change, then at most every 4 s, and only
while the on-screen UI is up, the world shows, the game is not paused and the menu is closed. A scan asks the engine for
the actors of each class (`GetAllActorsOfClass`, which reads its class hash). Up to 0.6.0-beta.1 it used `FindAllOf`,
which walks every object: 60 to 79 ms on the game thread at each scan, a freeze every 4 s. The class objects are found by
path once a map while they are in memory; one that is not is looked up again 30 s later. The fast route is checked once
a Lua load against `FindAllOf` on the player controller, and if this UE4SS cannot use it, scans walk as before. A scan
that is due still waits while EVE moves faster than 3 m/s (her run is 5 m/s) and runs once she walks or stops. A scan keeps each booth's `EnvActorName` and position, and no booth is read between scans.
Each scan is timed: `UE4SS.log` gets `booths: <n> on <map> (<ms> ms)` when the count or the map changes, and
`booths: slow scan <ms> ms (<n> found, <route>)` for a scan of 5 ms or more. The menu key opens the line when the nearest booth
is within 3 m of EVE. Nothing in the game changes: the mod edits no table row, spawns nothing and fires no zone event,
and the booth's travel and save stay the game's.

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
  native part writes your friend's lines into `coop-chat.txt` (`in <text>`, or `fail` for a line of yours that could
  not be sent) once Lua has taken the previous file, and Lua reads and deletes it every 250 ms. Both files are deleted
  when a session ends, when the native part starts and when the game exits. Chat text is written nowhere else. A crash
  dump (`Saved/Crashes`) holds the game's memory, so it may hold lines of the session.
- A Doro race uses the same pattern. Lua queues its race lines and writes all those waiting into `coop-race.txt` once
  the native part has taken the previous file, and the native part takes it at its next pass and sends each line in
  order. Your friend's race lines come in `coop-chat.txt` as `race <text>`, beside the chat lines, and Lua reads that
  file every frame while a race is armed. `coop-race.txt` is deleted with the chat files.
- `coop gift` sends its lines as requests (`gift <payload>` in `coop-request.txt`), and asks the inventory read the
  same way (`items ...`, answered in `coop-status.txt`). Your friend's gift lines, and a gift of yours that could not
  go, come in `coop-chat.txt` as `gift <payload>` ([Cut mailbox](cut-menus.md#cut-mailbox)).
- Two files are Lua's alone, for the [crash sentinel](ghost.md#cns-guard-and-crash-sentinel): `coop-cns-call.txt`, written in
  place with no temporary file to keep each write to one, and `coop-cns-aside.txt`, the set-aside list.

The full list is in [Settings](../settings.md#files-in-the-mod-folder).

## The co-op UI's input

The co-op menu, the guide, the co-op saves' question, the host's question, the chat box and the code box take the game's
input while they are open. The kit (`ui/kit.lua`) calls `SetInputMode_UIOnlyEx` with its root focused, or with the box's
text field for the chat box and the code box. The game's viewport then ignores every key and controller button, so EVE
stands still. The menu's keys are UE4SS key binds, which read the keyboard and the mouse buttons whatever has the focus.
When the UI closes, the kit gives the input back 150 ms later, so the key that closed it never reaches the game (Esc
would open the pause menu): `SetInputMode_GameOnly` in a world, and at the title `SetInputMode_GameAndUIEx` with no
mouse capture, so the title menu keeps its cursor. The game reads the keys of its own screens as player controller
actions (`UI_DPad_*`, `UI_FaceButton_*` and `UI_GameMenu` in its `DefaultInput.ini`), which need the viewport's input,
so its screens work again after the give-back.

### Controller

UE4SS cannot bind a controller button, and UIOnly makes the game ignore the controller, so the native part reads it
through XInput, a polling API that takes nothing from the game.

- The worker loads `xinput1_4.dll`, else `xinput9_1_0.dll`, with `LoadLibraryExW(..., LOAD_LIBRARY_SEARCH_SYSTEM32)`,
  and takes `XInputGetState` from it. The game's folder can hold another tool's `xinput1_3.dll` proxy, which is never
  loaded.
- `coop_pad` runs on the game thread. It reads slots 0 to 3 at most once per 8 ms, ORs their buttons and takes the
  first connected controller's left stick. A slot with no controller is asked again only after 2 s, and only one such
  slot per read, since asking an empty slot can cost milliseconds. While another process's window is in front nothing
  is read, and the held state counts as released: XInput answers whatever window has the focus.
- `game/pad.h` turns the reads into events: up, down, left and right from the D-pad or the left stick (pressed at 50 %
  of its range, released under 30 %), a D-pad diagonal read as up or down and the stick along its main axis (up or down
  when both are equal; an axis already pressed stays until the other is more than 10 % larger, so a stick held near
  45 degrees does not switch at each read), up and down repeating after 400 ms then every 120 ms, A for select, B for
  back, and View held 1000 ms for the menu, once a hold. A ring of 8 holds them; a full ring drops the newest.
- The DLL links no Lua, so each event travels as a result count. Lua calls `select('#', native_pad(0,0,0,0,0,0,0))`:
  `coop_pad`, called as a Lua C function, returns n, and Lua hands back the top n of the 7 arguments on its stack. n is
  the event, 1 to 7, or 0 when the ring is empty. `main.lua` takes at most 8 events a frame and routes them as the keys
  route theirs: the open menu gets the six navigation words and View closes it, the co-op saves' question gets up,
  down, select and back (the guide gets them first while it is open), the chat box and the code box get back only (it
  closes them), the host's question gets none, and with nothing open, in a world with the HUD shown, View opens the
  menu through the same path as `menu_key`.
- The worker logs each change of the connected slots (`pad: XInput pads connected: <slots>`, `pad: no XInput pad`).

### Mouse

While the menu or the guide holds the input, the kit sets the player controller's `bShowMouseCursor` after the input
mode and keeps the value it found. That value goes back when the input goes back, when a text box takes the input, at
`coop ui reset` and at `coop off`. A Ctrl+R with the menu or the guide open leaves ` cursor` beside ` input` in
`coop-ui.txt` (` cursor shown` when the cursor was already shown, as on the title screen), and the next Lua load puts
that value back as it gives the input back. The check that keeps the menu closed while one of the game's screens shows
the cursor ignores the cursor while it is the menu's or the guide's. Every 100 ms the menu asks its 15 drawn rows
whether the mouse is over them (`IsHovered`), and a row the mouse moved onto takes the focus. The `LEFT_MOUSE_BUTTON`
bind selects the row under the mouse and `RIGHT_MOUSE_BUTTON` goes back. Slate gives a click that none of the mod's
widgets takes to the game's viewport, with the keyboard focus, so while the UI holds the input either button has the kit
focus its root (or the box's field) again 50 ms later.

### Focus watchdog

The kit makes its root focusable (`bIsFocusable`) before it adds it to the viewport, so the input mode focuses the root
itself. Every 250 ms while the UI holds the input, it reads `HasAnyUserFocus` or `HasFocusedDescendants` on the root.
The watchdog arms at the first yes since the input was taken; armed, 1 s of no fires it once. `main.lua` then runs the
same function as `coop ui reset`: the menu, the chat box and the code box closed, an open host's question denied (which
fails closed), the co-op saves' question closed as Decide later (a copy pass already asked for keeps running and is
followed on, where `coop ui reset` withdraws it), the input given back at once and the menu's cursor put back. One log
line names the holder; nothing shows on screen. A root that never had the focus 2 s after a take leaves the watchdog
unarmed, with one log line a Lua load. The Steam overlay should keep Slate's focus where it was and then not fire the
watchdog (not tested in game yet). The game, another mod, or a middle or side mouse button moving the focus does.

### Line breaks

Every text the mod wraps goes through `session/chat.lua`'s `wrap`: the chat feed and history, the notice line above EVE
and the co-op saves' question. The kit's UMG texts never wrap on their own. A row breaks at the last space within reach,
else between two characters (Chinese, Japanese and Thai put no space between words), and a mark that takes no column
(Thai and Arabic vowel and tone marks) stays with the letter before it. Thai writes the vowels U+0E40 to U+0E44 (เ แ โ ใ
ไ) before the consonant they follow in speech, so a row never ends on one: between two characters the cut moves back
before such a vowel, unless the row would be left empty.

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
