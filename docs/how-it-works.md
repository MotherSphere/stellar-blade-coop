# How StellarCoop works

For the commands, see [usage.md](usage.md). For the code layout, see [building.md](building.md#repository-layout).

## Lua and native parts

StellarCoop has two parts, both in the mod folder `Mods/StellarCoop/`:

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
| `commands/cut.lua` | `coop leviathan` and the other viewer commands (`gardener`, `tendril`, `mann`, `nier`, `orcal`, `enya`), with the co-op save check before `show` and before `cam` turns the camera on; `coop lion`, with the co-op save check before the words that spawn; `coop wear`; `coop scene`, with the co-op save check before a scene's name; `coop lines`; `coop fly`, `coop slowmo` and `coop glide`, with the co-op save check before `on` |
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
| `nightop/waves.lua` | The run's waves, keys, score, timers and states, read from a definition, alone or for two players, the pairing of new bodies with their spawn spots, and the night line's two formats, with no engine call |
| `nightop/run.lua` | The `coop nightop` run and the `coop challenge` runs: start checks, the host's ask and the guest's answer, spawns, the monsters it tracks, the night line, its card and result panel |
| `nightop/shop.lua` | Night Operation's reward shop: the points file, `coop nightop shop` and `buy`, and its one item request |
| `nightop/challenges.lua` | The challenges' waves and rules, the `coop challenge` list and the best runs in `coop-records.txt`, with no engine call |
| `nightop/recruiter.lua` | The `coop recruiter` preview |
| `nightop/recruiter_text.lua` | The recruiter's lines in the game's 23 languages |
| `race/doro.lua` | The display Doro (a plain actor with Doro's mesh, animated by the engine's single-node animation), the Doro look on your EVE, and `coop race probe doro` |
| `race/model.lua` | Doro races with no engine call: the track file, the rules, the start slots, the host's and the guest's race over the race lines, and the ranking |
| `race/run.lua` | Doro races in game: recording a track, the race run from EVE's feet, its HUD, its Doros and its notices |
| `cut/leviathan.lua` | `coop leviathan` and the other viewer commands: one table of seven cut models (Naytibas 10, 1 and 6, the early Mann, the NieR machines, Orcal's and Enya's prototypes: their meshes, animations, default distance, height and scale, skins) and one viewer for them. It reads a creature's assets and CharacterTable rows, shows one of its meshes playing its animations on a display like the Doro's (one creature at a time) and flies a free camera to film it |
| `cut/lion.lua` | `coop lion`: the cut Lion's rows asked of the native part and read back, its spawn, its entrance on a display copy, the lines that follow it ([The cut Lion](#the-cut-lion)) |
| `cut/lion_rows.lua` | The Lion's rows as `lion/rows.h` writes them, for the read-back, and its Shows for the loaded line; written by the rows' generator |
| `cut/lines.lua` | `coop lines`: the timing of four cut scenes' subtitles (each line's start in its level sequence with its `StringTable_Seq` key or its section's number, read offline), their text read from the game when one starts (`TextFromStringTable`, or the sections of Sky Hall's loaded test sequences) and said into the chat's feed at those times |
| `cut/glide.lua` | `coop glide`: sets EVE's `bGlide` while Jump is held in the air past the top of her jump, and clears it ([Cut glide](#cut-glide)) |
| `cut/wear.lua` | `coop wear`: sets the mesh of EVE's body or hair component (with the hair's animation Blueprint and physics asset) to a cut suit or hair and keeps the game's own look in `coop-wear.txt` to give it back. It puts the worn look on again when the game sets its own |
| `cut/scene.lua` | `coop scene`: two unused rows of the game's theater table pointed at a cut scene's theater and read back, the Emil farewell's take lent to E03, E03's subtitles registered for the game's language, the theater observer it follows once a second and the Stop row that ends it |
| `core/unreal.lua` | Small helpers over UE4SS objects |

`main.lua` runs two game-thread loops. One runs every frame: the ghost's build step, `coop_tick`, placing the ghost, the
Doro look, the cut model display and free camera, `coop lion`'s waits and lines, a Doro race (with the incoming lines
while one is armed), the notice line, the previews' follow-ups, the `coop wear` check (once a second), the `coop lines`
scene's due lines, the `coop glide` check, the UI's open and close animations, the game's input given back after the
menu or the chat box closes, the controller's events, the row under the mouse (every 100 ms while the menu is open), and
your friend's marker and gauges. The other runs every 250 ms: link status changes, session start, notices to show, chat
lines in and out, Night Operation's run, the race's session and map checks, the UI's root and its focus watchdog, the
menu's rows and status line, the phone booth scan, the chat's feed, your friend's card, the capture and the remote
table.

The [co-op line](usage.md#co-op-line) opens at the camp phone booths that the levels place, actors of two classes:
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
  table), `coop-cns.txt` (the assets your CNS packs declare, once at start), `coop-link.log` and `coop-report.txt`.
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

The full list is in [usage.md](usage.md#files-in-the-mod-folder).

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

## The Steam link

The link runs in the native worker, through the Steamworks API that the game itself loaded and started (the game's
`steam_api64.dll`, flat API, SDK 1.59). StellarCoop does not start Steam or call `SteamAPI_Init`, and linking changes
nothing in the game or the saves. If one of the Steam functions it needs is missing (another Steamworks build), the
worker and the pose path stop for the rest of the run, and the status file says `missing=<name>`.

One worker thread makes every Steam call. The game's Steam callback thread only stores a few numbers for it. The worker
runs a pass every 50 ms, or every 5 ms while poses flow (the loopback, a recording, a replay or a friend).

### Lobby and invites

- `coop host` creates a friends-only lobby with room for 2 players and opens Steam's invite dialog. With
  `who_can_join=private`, Lua asks for `host private` instead, and the lobby is a private one that only invited friends
  can join. The lobby carries a tag under the key `stellarcoop`: the protocol and the game's Steam build
  (`12:<build>`). A lobby from another protocol or game build is refused on joining, with both versions in the joiner's
  log and on screen. A lobby with no tag is another game's, and is refused as such.
- The native request `host code` creates an invisible lobby (Steam's `ELobbyType` 3): anyone who has its id can ask
  to join, and the host's friends do not see it. Steamworks documents that a lobby search still returns it.
  StellarCoop never searches, and a player who finds it that way waits for the host's answer like any other player
  who is not a friend. No invite dialog opens. The host gets a 7-character join code instead (`CCS-CBMH`), on screen
  and in `coop-status.txt`. The request `copy` puts it on the Windows clipboard. Under Proton, Wine should pass it on
  to the desktop's clipboard; the Wine smoke test checks the Windows side only. `join <code>` joins the lobby it names.
- The code holds the low 32 bits of the lobby id in Crockford's base 32, which leaves out I, L, O and U. Every lobby
  id seen so far starts with the same high 32 bits, `0x01860000`, which the code leaves out. The 3 spare bits hold the
  low part modulo 7, so 89% of the codes with one character wrong are turned away (over 2,000 random ids) instead of
  leading to another lobby. Either case is accepted, I and L read as 1, O as 0, and the dash is optional.
- An accepted invite arrives as a Steam callback, or as `+connect_lobby <id>` on the command line when Steam starts the
  game for it. Either way the game joins only once a save is loaded (Lua writes `world=1` in `coop-state.txt`), so a
  launch never joins from the title screen. Until then the invite is held.
- `coop join` without an id searches your Steam friends for one who is playing Stellar Blade in a lobby.
- The host leads. When the host leaves, the guest leaves too, even though Steam would hand the lobby to them. A lobby
  with more than 2 players is left.
- When a guest's game loses the host's lobby another way, it rejoins automatically: it tries at 2, 12 and 42 s and
  gives up at 60 s. A lobby that is gone or has a new owner by then ends the session.

### Players who are not Steam friends

In any lobby, a player who joins and is not the host's Steam friend waits for the host's answer. The host's game holds
the handshake: it sends no hello and reads none of the player's messages, only pings them so that neither game reports
a lost connection. The host's status shows `pending=<SteamID> <name>` and a notice says that a player who is not a
Steam friend is asking to join. The joiner's game shows `Joined <host>'s game. Waiting to be let in.` The host
answers with native requests, which Lua writes to `coop-request.txt` like the others:

- `allow <SteamID>` lets the player in. The handshake then runs as with a friend, and a rejoin after a drop is let in
  without a new question for as long as the lobby lasts.
- `deny <SteamID>`, or 60 s with no answer, refuses the player, and so does leaving before the answer.
  `remove <SteamID>` refuses any player already in, friends included.
- A refused player gets a `SBC reject` with the reason (`you were not let in`, `no answer within 60 s`, `you were
  removed from this session`). Every build since protocol 9 shows it as `<host> refused the link: <reason>` and leaves. That
  player stays refused until the host creates a new lobby: the host never greets them again, ignores their session
  requests and messages, and sends `you cannot join this session again` each time they come back. Steam has no way to
  remove a lobby member, so a game that ignores the reject keeps the second place in the lobby. It gets the reject
  again every 10 s, and the host can create a new lobby, which gets a new code.
- Answers go by SteamID, so an answer meant for a player who left never reaches the next one. A guest's answers, and
  an answer for a player who is not waiting, are ignored with a line in `coop-link.log`.

On the host, `session/join.lua` turns the first `pending=` line into a question on screen and writes the answer. It asks
each player once a lobby; with no answer, the native part refuses the player after 60 s. The question opens without a
key press, so it ignores every key for 1 s after it shows, and `main.lua` gives it the arrow keys but not W, S or Space.
`core/link.lua` keeps in memory which lobby members waited for an answer, for the menu's Remove row, so a Lua reload
forgets them.

None of this adds a line to the protocol: it uses the hello's timing, the ping and the reject.

### Handshake

Once both games are in the lobby, they exchange a hello on channel 0:

```
SBC hello <protocol> <mod version> <game build>
SBC accept
SBC reject <reason>
```

The handshake format is the same in every protocol version, so a peer on another version always gets an answer. A
peer whose protocol or game build differs from yours is rejected, with both versions in the reason, and both leave
the lobby. The side that rejects shows `Version mismatch with <name>: ...`, the other `<name> refused the link: ...`.
The mod version is reported but does not have to match.

A friend who passed the handshake both ways is linked (`peer linked: poses and tables go over Steam` in
`coop-link.log`) while the native pose path is on (`engine=on`) and no loopback or replay runs. The ghost turns on with
the session (the link going from none to host or guest). That publishes your EVE's capture and builds the ghost of
your friend's EVE, which stands where her main mesh is, with no offset.

### Channel 0: text

Channel 0 carries short text messages over Steam's relayed P2P messages (SteamNetworkingMessages). Apart from the
handshake, every message carries the protocol number, and a peer that runs another protocol drops it:

```
SBC13 ping <seq> <ms>
SBC13 pong <seq> <ms>
SBC13 photo <0|1|s|c> <both|notice>
SBC13 say <text>
SBC13 vit <hp> <max hp> <shield> <max shield> <shield blocks> <beta> <max beta> <burst> <max burst> <tachy> <max tachy> <life>
SBC13 pak <hash> <name>
SBC13 paks <count> <hash>
SBC13 camps? <id>
SBC13 camps <id> <world> <camp>:<m> ...
SBC13 camps <id> none <title|loading|nocamp|busy>
SBC13 night h <n> <run> <seed> <phase> <wave> <run time ms> <score> <kills> <clears> <found> <x> <y> <z> <yaw> <map> <end>
SBC13 night g <n> <run> <state> <up> <killed> <done> <why>
SBC13 mark <n> [<text>]
SBC13 race <text>
```

The photo line is sent reliable. It carries the sender's photo mode (`1`, `s` for selfie mode, `0`) and whether their
game may be paused for the other player's photo mode (`both`). It is sent after each handshake and on each change, and
the receiver takes at most 8 a second. While your friend's line says `1 both` and your setting is `photo_sync=both`,
the game thread holds a pause tag of the mod's own in the game's pause set. It sets the tag through the function that
the game's photo mode pauses with (build 24463856 only). [usage.md](usage.md#synced-photo-mode) lists when the pause is
released. A host's line says `c` while a cutscene plays in its game and its own photo state is `0`
([Cutscene wait](#cutscene-wait)).

The say line is one chat line, sent reliable. Both games clean it the same way: they keep well-formed UTF-8 only, drop
control, bidi and zero-width characters, trim spaces, and keep at most 200 bytes, never cutting inside a character.
At most 3 lines a second are sent, and at most 10 a second are kept from a friend. The rest are dropped, with one log
line a minute that holds no text. At most 64 received lines, chat and race lines together, wait for the Lua side. The
text never goes into `coop-link.log`, `coop-status.txt`, `coop-report.txt` or the console. When the session ends, the
log gets the counts only: `chat this session: <n> in, <n> out, <n> dropped; race lines: <n> in, <n> out, <n> dropped`.

The vit line is sent unreliable. It carries your EVE's numbers for your friend's partner card, in whole units: HP,
shield and shield blocks, Beta, Burst and Tachy with their maximums, and the life state. It is sent when a number
changes, at most 10 times a second, and once a second otherwise. During a session the native worker reads the numbers
every 100 ms, or 500 ms after a read that took over 1 ms (game build 24463856 only). Each read is eight
`ReadProcessMemory` calls on the worker, never on the game thread, on the EVE that the game's actor manager marks as the
local player. A vit line is invalid if a value is over 10,000,000, HP is over its maximum, there are more than 64 shield
blocks or the life state is over 255. Your friend's last line shows in `coop status` as `mate=` for 3 s.

The pak and paks lines are sent reliable, once after each handshake. At start the native part lists the files under
`SB/Content/Paks` (eight folders deep, 4096 files at most) and leaves out the base game's own
(`pakchunk<n>-WindowsNoEditor` and `pakchunk<n>optional-WindowsNoEditor`, `global`). The `.pak`, `.ucas` and `.utoc`
files of one name make one mod container, and each container goes in a pak line: a 64-bit hash of its files' paths and
sizes in 16 hex digits, then its name, which is its path from `SB/Content/Paks` in lower case with `/`, without the
extension (`logicmods/hd-atool_p/hd-atool_p`). In a name, spaces, commas and bytes outside printable ASCII become `_`,
and it keeps 100 bytes at most. Up to 256 containers go, sorted by name; with `mod_names=off` in `coop-settings.txt`,
none. The paks line comes last and ends the list. It carries the number of `.pak` files left and a 64-bit hash of their
paths and sizes, and of their `.ucas` and `.utoc` files. The header of `coop-link.log` names those `.pak` files
(`paks <n> beyond the base game, hash <hash>: ...`).

When your friend's hash differs from yours, `coop status` has `paks=differ <yours> <theirs>`; with the same hash it
has `paks=same`. When their list came with names, three lines follow it: `mods_missing=<n> <names>` (theirs that you
lack), `mods_other=<n> <names>` (the same name with another hash: another version) and `mods_extra=<n> <names>`
(yours that they lack). Each line has the count, then the first names separated by commas, 400 bytes at most.
`coop-link.log` names the ones you lack and the other versions each time their list changes
(`<name> has mods we lack (<n> <names>) and mods we have in another version (<n> <names>)`). Once a session, a notice
names the mods you lack and then the other versions, up to two file names each (see
[usage.md](usage.md#shared-enemies-experimental)). Without names, or with only mods of yours that they lack, the notice
gives the two counts. Nothing is refused: enemies that differ already stay unshared (same character id and maximum HP
for each pair).

The same scan counts the CNS packs (`*.dekcns.json` files of the Custom Nanosuit System under `~mods`, 256 at most,
the first MiB of each) and their outfits (their `UniqueFitID` keys). With at least one pack, the header of
`coop-link.log` has `cns <n> packs, <m> outfits, <k> assets`, the status a `cns=<n> <m>` line, and the Lua side logs
`CNS detected (<n> packs, <m> outfits)` and adds those words to `coop status`.

The scan also lists the assets the packs declare: each `/Game/...` string given as the value of an `OutfitPaths`,
`Mesh`, `Materials`, `PonyPhysics`, `Textures` or `Value` key (or in an array under one), 255 printable bytes at most,
8192 at most in all, each with the `UniqueFitID` given last before it. It is a bounded scan of the text, not a JSON
parser: it tells strings (with their escapes) and keys apart and skips `//` and `/* */` comments, which real packs
carry. Image and AnimBP paths are never listed. The list goes to `coop-cns.txt`, one `<path> <outfit>` line each,
rewritten at every start. It never goes to your friend: only the tag of an outfit your EVE wears does, in the
component table (see [The ghost pipeline](#the-ghost-pipeline)).

The camps lines carry the [follow](#following-the-host), both reliable: the guest's `camps?` with a number from 0 to
65535, and the host's answer to it, its world and up to 8 camps nearest its EVE with their distance in whole metres, or
`none` and why. Only the guest asks and only the host answers. The host's link takes one `camps?` each 2 s, and the
guest's keeps only the answer to her last number. A world or camp name is letters, digits and `_`, at most 64
characters. Both lines show in `coop status` (`camps?=`, `camps=`) until the session ends.

The night line carries a Night Operation run between the two games (see
[night-operation.md](night-operation.md#the-co-op-run)). It is sent reliable, and each line holds the whole state of
one side, so a lost line is repaired by the next. The host's `h` line has a counter, the run number and seed, the
phase (`ask`, `count`, `wave`, `rest` or `end`), the wave, the run time in milliseconds, the score, kills and waves
cleared, the wave monsters his run found and has not done (a hex mask), his start point, yaw and map, and the outcome
once the run ends (`success`, `time`, `failed:host`, `failed:guest` or `aborted:<reason>`). The guest's `g` line has a
counter, the run number, her state (`ready`, `refuse`, `run`, `dead` or `abort`), her monsters still up, masks of the
ones killed and done in her world, and a refusal or abort word. Each game writes its line when it changes and at least
once a second, never twice in one Lua tick, and logs each line out and in as `[StellarCoop][NR] night out: ...` and
`night in: ...`.

The native part checks only the bytes: 3 to 300 of `0-9`, `a-z`, `/`, `_`, `:` and `-` with single spaces between
words, the first word `h` from the lobby owner and `g` from the guest. It sends an `h` line only while it owns the
lobby and a `g` line only as a guest, and a received line from the wrong side counts as invalid. At most 8 lines a
second go each way; the rest are dropped, with one log line a minute. The last line received is the `night=` line of
`coop-status.txt` while the session holds, and is cleared when the friend is lost or the session ends. Lua checks every
field and refuses the whole line on one bad field. A co-op run ends as lost once the friend's counter has not moved for
5 s. No line carries points: each game turns its own run's final score into points, at most 42 a run.

The mark line is one `coop mark`, sent reliable to each friend past the handshake: its number in the sender's game
(from 1, one count per game process) and its text, cleaned as a say line is and cut to 100 bytes, maybe empty. A longer
text from a friend is cut, not refused. The receiver counts mark lines with say lines against the same 10 a second and
drops the rest, with one log line a minute (`dropped marks from <name>: over the rate limit`). Unlike a say line, the
text goes into `coop-link.log` on both sides (`mark <n>: <text>`, `mark <n> from <name>: <text>`) and into
`coop-status.txt` as the `mark=` line, which the Lua side copies into `UE4SS.log`.

The race line carries one line of a [Doro race](#doro-races), sent reliable. The link passes its text on as it is: it
reads no further, and only refuses a line with a byte outside printable ASCII (0x20 to 0x7e) or longer than 512 bytes
in all. At most 40 lines a second are sent, and at most 40 a second are kept from a friend. Your friend's lines past
that are dropped, with at most one line a minute per friend in `coop-link.log` (`dropped race lines from <name>: over
the rate limit` or `too many waiting`). Yours past it are only counted, in the session's end line. During
`coop loopback` with no friend linked, your race lines come back as your friend's.

Say, vit, pak, paks, camps, night, mark and race lines from a friend who has not passed the handshake are ignored, without a log line.

Accepted peers ping every 2 s. A peer silent on channel 0 for 10 s is marked lost (`<name> silent for 10 s: lost`)
until they are heard again; they stay linked and their table is kept. A message longer than 512 bytes is treated as
invalid.

A session request from Steam is accepted only after a live check that the requester is a member of your lobby. Any
other request is ignored.

### Channel 1: tables and poses

Channel 1 carries the pose path's bytes unchanged: the component table as text starting `SBT 13` (sent reliable), and
each pose as a binary message starting `SBP` (a keyframe) or `SBD` (a delta), then the protocol byte (sent unreliable,
without Nagle delay). Same-place enemies add a binary message starting `SBE` and the protocol byte, at most 30 a
second (sent unreliable): the place, rotation and animation speed of up to 16 enemies that the sender moves on the
other screen.

- Your table goes to your friend at once and again every 5 s, so a table lost with a broken session, or sent before
  they accepted, arrives with a later resend. An identical table is ignored. A changed capture (a new outfit, the
  blade drawn) goes at once.
- A table of theirs that needs a new ghost (a new generation or layout) is taken at most once every 2 s. One that comes
  sooner is refused (the stream line's `tables: ... refused`) and their next resend brings it.
- Poses go 60 a second by default (`send_rate`, 10 to 60), at most one per game frame: a game running at 45 fps
  sends 45. With deltas, 60 a second took 89 to 131 KiB/s in tests with simulated idle, running and combat motion on a
  5 KB outfit, and 20 a second 40 to 52 KiB/s. The sender holds a pose back while its poses would pass 192 KiB/s
  (176 KiB/s while it also sends `SBE`), under Steam's default send rate of 256 KiB/s.
- Channel 1 passes on only data from a lobby member past the handshake: at most 64 KiB a message, and 240 messages
  and 1 MiB a second per friend. The rest is dropped and counted, with at most one line a minute per friend
  (`dropped pose data from <name>: before the handshake`, `bad size` or `over the rate limit`). A non-member's data is
  logged once (`ignored pose data from <id>: not in our lobby`). Channel 1 traffic does not count as hearing from a
  friend for the 10 s lost check.
- Once they are out of the lobby (`<name> left the lobby`), or you left it, the log says `peer unlinked`, and their
  table and the ghost are removed (`Ghost <generation> removed (her table is gone).`).

### Protocol versions

The protocol number goes up with any change to what travels between two games, so an older StellarCoop is refused
instead of misread:

| Protocol | Change |
| --- | --- |
| 1 | The first link (a hello with a name, no accept or reject) |
| 3 | The component table (`SBT`) beside the pose (`SBP`) |
| 4 | Tables and poses carried on Steam channel 1 |
| 5 | The table's material lines (dyes) |
| 6 | Four effect slots in each pose |
| 7 | Steam channel 2 for the shared enemies, and the photo line |
| 8 | The say and vit lines, for the chat and the partner card |
| 9 | Poses sent as deltas against a keyframe (`SBD`) on Steam channel 1 |
| 10 | The shared enemies' scale line: the host's enemy HP and balance multipliers; the paks line |
| 11 | Same-place enemies: `SBE` on Steam channel 1; the show lines, the host's place, aggro and own lines and the guest's own-no lines on channel 2; same spawns' epoch, have, spawn and drop lines; the host's bosses, bstart and phase lines and its summons' spawn lines |
| 12 | Shared quests: the `SBQ` lines on channel 2; the `camps?` and `camps` lines, the photo line's `c`, Night Operation's night line, the mark line and the Doro races' race line on channel 0 |
| 13 | The pak lines: each mod container's name and hash, before the paks line; the table's cloth and mod lines, and mod paths outside the game's folders (this version) |

### Link health in the log

Every 60 s, `coop-link.log` has one line per linked friend (`<name>, last 60 s: ...`): messages and KB/s in and out on
channel 1, drops, failed sends with the last Steam result (25 means its send buffer is full), the ping's RTT average
and maximum, pings sent and pongs received (the difference is ping loss), and Steam's view of the session: quality
local and remote, send rate, pending unreliable bytes and queue time.

## The ghost pipeline

The ghost goes through the same pipeline whatever its source: a linked friend, the loopback or a replay.

### 1. Capture

When the ghost is on, `partner/capture.lua` describes your EVE once she has been in the world for 2 s (never on a menu
pawn). It only reads. For each skeletal mesh part (up to 16, with up to 1024 bones each) it notes the mesh path, the
part it follows, the part and socket it hangs from, its placement there, whether it is shown, a leader's bone names,
and the map she is on (the package path of her world, lowercased). With the dyes look on, it adds each part's
overridden materials. With the effects look on, it adds what the native part needs to read her effects. A part whose
ponytail cloth has a collision asset of its own (`OverrideClothPhysicsAsset`) names it.

A mesh outside the game's own folders (`/Game/[DLC_<n>/]Art/Character/`) comes from a mod. Such a part gets a tag: the
`UniqueFitID` that your CNS packs give its path (from `coop-cns.txt`), else the first two folders of the path
(`OutfitMods/FooSuit`). It also names its overridden materials with the dyes look off, since CNS sets an outfit's
materials when it puts the outfit on. With `mod_names=off`, no path outside the game's folders goes: such a mesh goes
as `-`, with no tag, and such a material or collision asset is left out.

The native part refuses a table whose pose would pass 16 KiB (about 900 leader bones in all). Before it publishes, the
capture counts the pose as the native part does and leaves out the last leader parts, with their followers, until it
fits; its log line then ends with `<n> leaders left out, over the pose size`.

It reads her again once a second. A new mesh (her outfit) starts a new generation. A part hung elsewhere (the blade
drawn or sheathed), shown or hidden is published again under the same generation. The log gives a `Capture` line per
generation.

### 2. The component table

The capture becomes the component table: one plain-ASCII grammar used for the capture file, the wire and the remote
table handed to Lua. In order:

```
SBT <protocol>                                    the wire form only
generation <1 to 2^53>
map /<package path, lowercased>
part <i> <lead|-> <parent|-> <socket|-> <shown 0|1> <bones> <name> <path|->
place <i> qx qy qz qw tx ty tz sx sy sz           parts after 0: placement relative to the parent
material <i> <slot> <path>                        up to 16, slots 0 to 63 rising: an overridden material
cloth <i> <path>                                  optional: the collision asset of the part's cloth
mod <i> <tag>                                     optional: on a mod's mesh, the outfit it comes from
names <i> <bone>...                               leaders only: one per bone
```

The capture file also carries the memory addresses the native part reads from (`read`, `effects` and `effect` lines);
those never go on the wire. A leader part has bones of its own. A follower follows a leader's bones (her ponytail, for
example). Part 0 is her main mesh. A table is at most 64 KiB, and the native parser checks every line (the tests fuzz
it).

### 3. The pose codec

While poses are wanted (the loopback, a recording or a linked friend), `coop_tick` reads and encodes EVE's pose on the
game thread at the send rate, and the worker sends it. A pose message holds:

- a header: `SBP`, the protocol, the table's generation, a sequence number, the sender's clock when the pose was read,
  and a hash of EVE's map;
- the main mesh's world transform: translation as three floats, rotation in 6 bytes, scale in three 16-bit integers;
- each leader's bones in local space, 18 bytes a bone: rotation as the smallest three of its unit quaternion (6 bytes),
  translation in 1/32 cm and scale in 1/4096 (16-bit integers each);
- four effect slots of 15 bytes each: an index into a fixed list of effects (never a path), the part it hangs on, a
  serial for each new instance, and its rotation and translation relative to the part.

A pose is at most 16 KiB; in the outfits measured it is 4.7 to 5 KB. A world position beyond 1e7 cm, or not finite,
is refused.

Since protocol 9 most poses go as deltas. A keyframe is a full pose as above. A delta has the same header, the age of
its keyframe in microseconds, the world transform, one bit for each bone rotation, translation, scale and effect slot,
and the bytes of those that changed since the keyframe. The sender sends a keyframe first, then every 250 ms, and
whenever a delta would not be smaller. The receiver rebuilds the full pose from the keyframe it holds and decodes it
like a keyframe, so a delta gives exactly the same pose. A delta whose keyframe was lost on the way is dropped and
counted as keyless; the ghost waits for the next keyframe, at most 250 ms later. In tests a delta was 26 % (idle) to
41 % (combat) of the full pose.

### 4. Playback clock and interpolation

The receiving side keeps the last 24 poses (400 ms at 60 a second) and draws the ghost a little in the past, so a late
pose still arrives before it is needed:

- The clock tracks the lowest one-way lag seen (which, between two PCs, includes the offset between their clocks). It
  drops to any lower lag at once and otherwise rises 1 ms a second, so it follows drift both ways. A lag that stays
  250 ms above it for 5 s (a clock step) moves it at once.
- Without jitter the ghost is drawn 1.5 send intervals behind the newest pose. With jitter it is drawn far enough back
  that a late pose is still ahead of it (the recent jitter peak, decaying, capped at 250 ms).
- The send interval is the time between two poses' publications divided by the difference of their sequence numbers,
  so lost poses, or the deltas dropped after a lost keyframe, do not push the ghost further back.
- Between two poses the pose is interpolated. Past the newest one it is extrapolated by at most half an interval.
  After 3 s without a pose the old ones are dropped, so the ghost never slides across the gap.

Poses that belong to no table, or to a table the ghost is not built on yet, are counted as foreign and not drawn.

### 5. The ghost, built from the table

When a remote table arrives, the native part checks it and hands it to Lua as `coop-remote.txt`. `partner/puppet.lua`
builds the ghost from it:

- The ghost is a plain actor with one PoseableMeshComponent per part and no collision (the
  [solid partner](#solid-partner) adds one capsule when it is on). It is not a Pawn, so lock-on, AI and saves leave it
  out.
- It is built one mesh a frame, which spreads the loading over several frames. Each part loads the mesh its path names.
  Loading only brings a cooked game asset into memory: nothing is worn or unlocked. Each part keeps the mesh's own
  materials (unless the dyes look is on), so the ghost wears the captured outfit.
- Two kinds of path pass the native path rule: the game's own (`/Game/Art/Character/...` and
  `/Game/DLC_<n>/Art/Character/...`, names of letters, digits and `_`) and a mod's (`/Game/<folders>/<asset>.<asset>`,
  names of letters, digits, `_` and `-`, 255 bytes at most). A path is always a package's own asset, so never a
  Blueprint class or a sub-object. The rule checks the text only. Before any lookup or load, `partner/puppet.lua` lets
  a mod's path through only when one of your own CNS packs declares that exact path (`coop-cns.txt`), so a friend's
  table cannot make your game load anything your installed outfits do not name. After a load, the asset must be of the
  expected class (a skeletal mesh, a material, a physics asset) or it is not used.
- A mod's asset that `LoadAsset` does not find (it looks in the cooked asset registry, where added assets usually are
  not) is loaded through `AssetRegistryHelpers:GetAsset` with an asset data holding only its path, which loads it by
  path. This is still one asset a frame. The build line lists each mod asset with how it came (`in memory`,
  `by LoadAsset`, `by GetAsset` or `missing`).
- Each part gets the render flags of every EVE part in the game's Blueprint: lighting channels 0 and 1, and custom
  depth with stencil 10, the game's value for the player.
- Parts hang as the table says (parent part, socket, placement), and followers follow their leader. There are no
  morphs (a neutral face) and, without the cloth look, the ponytail is rigid. The ghost always draws its highest
  detail level, so it never pops as it walks away.
- The ghost stays hidden until the first pose and after a second without one, so it never stands frozen. Your friend's
  Steam name (or `loopback`, `replay`) stands above it, turned to the camera at each pose. The tag's font has only the
  Latin-1 characters: any other shows as `?`, and a name that would lose more than half its characters shows the
  partner card's word for them instead (`Partner`, in your language when the font has its letters). A name tag that
  fails is left out and the ghost stays.
- The same generation with a part hung elsewhere, shown or hidden is applied to the ghost in place. A new generation is
  a new ghost. The `Ghost ... built` log line gives the parts, the meshes loaded and their time, those on the base suit
  (with how many of its bones follow) and those left out.

Lua then names what it built in `coop-display.txt`. Each frame, `coop_tick` writes the leaders' bones into the ghost
behind the engine's own CopyPose write gate, and writes the main mesh's world transform into a mailbox: a scene
component that nothing else moves. Right after the native tick, Lua places the ghost's root from the mailbox. A write
that the engine's gate refuses is logged once each time the native part takes a new ghost or a new capture generation
(`write refused: ...`).

### 6. Fallback: the base suit

A part falls back to the base suit when the path rule refuses its path, when your CNS packs do not declare a mod's path,
when your PC cannot load the mesh (a DLC you do not own, a mod you lack), or when a leader's mesh has other bones than
the table's. The body falls back to `CH_P_EVE_08` and the hair to `EVE_HR_01`, and each of the fallback's bones follows
her bone with the same name. Another leader whose mesh has other bones is drawn on that mesh the same way, so a head
replacer you lack still shows the original head. A part with no fallback is left out, with the parts that follow it.
`coop basesuit` forces the base suit for the body and hair.

When a part with a mod tag ends up on a fallback or left out, the ghost names the tags once per generation, on screen
in the menu's language (see [usage.md](usage.md#mods-and-cns-outfits)), and in the build line
(`mod parts not shown: ...`).

### 7. Map gate

The ghost is built only when the table's map is the one you are on. Otherwise the log says once
`Ghost hidden: she is on <map>, you are on <map>.`, `coop status` shows `ghost=hidden map`, and the poses that arrive
are counted as foreign. After a level change the ghost is removed. It comes back once your EVE has been in the world
for 2 s and the maps match. A ghost left standing by a Lua reload (Ctrl+R) is found and removed at the next load.

### Looks

The three looks (cloth, dyes, effects) use the same pipeline. Dyes add `material` lines to the table (parts on a mod's
mesh have them either way). Effects fill the pose's four slots, and the native part writes the drawn slots into four
boxes beside the mailbox, from which Lua starts and moves the effects. Effects have their own fault latch, so a fault
there turns effects off for the run and the ghost stays. See [usage.md](usage.md#looks).

Cloth, on by default, uses only the table's `cloth` line (sent whatever the setting): each PC runs NvCloth on the
ghost's ponytail from the body bones that already arrive (her hair chain `Ab-TL-HairB01` to `HairB09` among them). While
the ghost is shown, its root moves without the engine's teleport flag: a teleport clears the cloth's inertia, and the
strands would hang without trailing. It teleports when the ghost shows again and when it moves more than 2 m in one pose
(a fast travel, a respawn). The cloth simulates only while the ghost is drawn (`VisibilityBasedAnimTickOption` 3):
hidden, off screen or behind a wall for more than 1 s, it costs nothing, and it starts again from the bones when the
ghost is drawn again. The ponytail's cloth part is set up as SB sets up hers: the 18 body bones its collision bodies
hang on (`AdditiveMasterBoneArray`), the collision asset as `OverrideClothPhysicsAsset` (the table's `cloth` line, else
the outfit's `<body mesh>_PonytailPhysicsAsset`), then its leader, then its mesh, which creates the cloth. Each asset is
loaded in a build step of its own: the named one before its part's step, the outfit's after the body's.

### Solid partner

With `collide=on` (experimental, off by default, not tested in game yet), `partner/puppet.lua` adds one CapsuleComponent
to the ghost the first time the ghost shows. The capsule copies your EVE's movement capsule: its radius and half height
(40 and 95 cm in this build) and its height above her feet (her mesh's offset, 97 cm). It hangs on the ghost's main mesh
with an absolute rotation, so it stays upright. Its object type is your capsule's own (channel 24, `PawnCollision`, in
this build), and it blocks that channel and ignores every other. Your EVE's capsule blocks channel 24, the game's
monster capsules ignore it and NPC capsules have another type, so only your EVE meets the ghost. If your capsule does
not block its own type, the ghost's capsule takes WorldDynamic instead, which your capsule blocks. Monster capsules
block WorldDynamic too, so in that case the enemies whose AI runs on your PC stop at the ghost as well; the build line
then says `ours type 1`. The capsule has no overlap events and cannot be stepped on. The ghost's parts, its name tag and
any effect started on it have no collision. A Pawn profile would do nothing, since EVE's capsule ignores the Pawn
channel.

The capsule is QueryOnly while solid, and solid only while no rule opens it. `place()` checks the rules every frame,
right after it moves the root, and calls `SetCollisionEnabled` only when the answer changes:

| Rule | Open while | For |
| --- | --- | --- |
| a | `collide=off`, or the ghost hidden | A hidden ghost never blocks |
| b | the two capsules overlap by more than 1 cm, then until 20 cm past touching | The ghost moves by teleport, so it can only step into your EVE; it lets her through, and her movement pushes her out of an overlap of 1 cm or less |
| c | your feet 60 cm or more apart in height | One EVE on the other's head, on a ladder, or on an elevator that moved in one game only |
| d | your movement mode other than Walking, NavWalking or Falling | Swimming, climbing, ziplines |
| e | 2 s of contact (within 5 cm) with no gap of 0.5 s, then until 50 cm apart | A friend standing in a doorway; a ghost that steps back for a pose does not restart the 2 s |
| g | your friend's vitals missing for 3 s, or down | A downed friend can be reached for a revive |

Rule g applies to a friend's ghost only: a replay and the loopback have no vitals. Rule f, which would tell a dodge from
a run, is not built yet, so a dodge into the ghost stops at it, where it passes through an enemy. The start of each
contact logs one line with your speed, `GetMaxSpeed()`, `MovementMode` and the move's root motion data, to find that
rule in game. The capsule's build line logs your capsule as read, the camera boom's probe channel and the ghost's other
parts with collision on (0 expected). `coop status` counts the capsule's changes by rule (`changes=`).

Nothing goes over the network for it, and neither game's state changes: each PC decides for its own EVE. The ghost
shows your friend about one ping late, so the two PCs never agree on a contact, and nothing depends on them agreeing.

## Same-place enemies

Same place (`same_place`, experimental, the host's value, on by default, not tested in game yet) builds on shared
enemies: the same pairs, the same host and the same Steam channel 2. Each pair has an owner, the game whose copy runs
the enemy's AI and moves it; the other game draws its copy (stages 3a and 3b of Phase 11). The host decides the owner.
HP, Shield, balance and death stay with the host's game whoever owns the pair.

- The host's `same_place` decides for both games. The host sends it as `SBF13 place <gen> <0|1>` after its world line
  (and its scale line) while it is on, and again at each change, `coop fight pilot off` and an error included. The
  guest draws her copies only while the host's last place line says 1, and forgets it with the host's next world, on or
  off line. Her own value is not read at a start: her co-op menu row only stops same place on her side, or starts it
  again, while shared enemies wait or run (`coop fight pilot off` and `on`).
- Every pair starts as the host's. With `aggro=game` (the host's setting, the default) the host's job runs a rule on
  each pair every turn: the pair goes to whoever hit it last (a hit on the host's copy, or a claim of hers that lowered
  a stat), and after 10 s without a hit to the other player once that player's EVE has stood at least 3 m nearer, and
  within 30 m of it, for 2 s (the force target that follows makes that EVE the enemy's last player, which counts as
  taking part in its fight: [Achievements](#achievements)). Nothing changes hands within 4 s of the last change, while
  an AI task runs on the owner's copy, during Down, Groggy, Airborne or a takedown, while the enemy dies, or while the
  host draws a copy that the game froze before the mod did (below: its AI would not run once the host owns it); the
  start of a takedown is the exception (below). Each change moves the owner epoch one up and goes to her as
  `SBF13 own <gen> <hguid> <H|G> <oe>`; the host freezes its copy as it sends own G and thaws it as it sends own H. With
  `aggro=host` the host keeps every pair (stage 3a). The host sends `SBF13 aggro <gen> <game|host>`.
- The guest takes an own G only at her epoch plus one, for a paired copy in life state 1 while same place runs on her
  side, and thaws her copy in that turn. She refuses a copy that the game froze before the mod did (why `state`),
  except for her takedown. Otherwise, and when she can no longer run a pair she owns, she answers
  `SBF13 own-no <gen> <hguid> <oe> <why>`, where why is `unpaired`, `state`, `off`, `epoch`, `aggro`, `full` or
  `target`, and the pair is the host's again. After `off` or `aggro` the host hands her nothing for 30 s, and after any
  other reason not that pair. A world line, an on or an off line starts the epochs over on both sides and ends both
  pauses.
- In the frame a hand-over makes a pair a game's own at a new epoch, its game thread first puts the copy back
  (below), then calls the game's force target function (`FUN_141a36010`) toward its own EVE: detect result 3, aggro
  level 1, and the game's own TargetedByEnemy jobs. The call runs only with the cached net mode 0 (in net mode 3 that
  function would send server requests), no logic task in flight, the two game objects it fetches already made (their
  getters would make them), the copy found by its GUID, its own EVE found and an AI owner on the copy. A task in
  flight or a copy not found puts it off for up to 250 ms. A refused take-over goes back to the job, and the guest
  gives the pair back with `own-no target`. A pair that comes back to the host after an own-no or
  place 0 gets no call: the host's copy keeps the target it had.
- Every 33 ms the owner's game thread reads each enemy it owns: position, rotation, animation speed, BattleMode,
  whether it is dying and whether an AI task runs, into one `SBE` message on channel 1 (26 bytes an enemy, 16 enemies
  at most), stamped with the pose clock. It also walks the game's Show manager (the game's animation sequences) for the
  Shows each enemy starts, and sends `show`, `show-set` and `show-stop` lines on channel 2 with the asset's path and
  the hit context. It never sends a Show that one of its own replays started, so a pair just taken over sends nothing
  back. Only two lookups by GUID are called for this; the rest is plain reads.
- On the drawing side's logic thread, each copy gets the game's own BlockAI effect (2000100, then SkillCancel
  2004400), only in life state 1 and outside NoDamageNoHit. When the game takes it off, the mod puts it back, at most 5
  times in any 10 s (then `freeze-lost`: the copy stays an ordinary enemy). On every way out, and before a kill, the
  BlockAI dispel effect (2000101) takes it off. That dispel would also end the game's own BlockAI, and the game
  freezes some enemies from their spawn until an event of its own (a boss before its cutscene, the sitting LabMutants
  of AYL_02). Timed rows hold the same state too, such as LV_Sequence_Warp_Effect (7000144, 1 s). A copy that already
  holds state 39 when the mod first freezes it gets no effect from the mod and no dispel on the way out
  (`thaw skipped` in the log). When the game's freeze ends, by its own dispel or by running out, the next census finds
  state 39 gone and the mod freezes the copy as any other. A copy whose last dispel the game refused is the exception:
  its state 39 is the mod's, so the mod freezes it and dispels it again (it keeps the last 16 such copies).
- On the drawing side's game thread, each frame, each copy is found again by its GUID. Its movement component goes out
  of the game's parallel movement manager through the game's own function for that (only on the game's class with the
  game's function in that vtable slot), the speed override that the game's own MoveToLocation writes is set to the
  owner's speed, the root moves to the sample at the ghost's draw time, and Velocity follows the samples. Each Show is
  replayed through the game's Show handle API when the draw time reaches its stamp, with its hit context written into
  the new player. A Show that the drawing game started on the copy less than 1 s before (a hit's reaction, a
  mirrored crowd control, its death) and still plays is not replayed a second time.
- A copy that is knocked down, groggy, in the air or in a takedown is released: the game moves it until 200 ms after
  that ends, then it blends back to the stream over 300 ms (a snap beyond 2 m).
- Takedowns (stage 3c). Each pass reads two takedown markers in a copy's effect list, `Check_LinkSkillHit_Skill`
  (5000039) and `LinkState_MonsterHit` (2006004). When one shows on the guest's copy while same place runs on her side
  with `aggro=game`, she sends `SBF13 exec <gen> <hguid> 1`, and `SBF13 exec <gen> <hguid> 0` once her copy has held
  none for 200 ms, or at once when the copy dies or goes (a turn between the two markers ends nothing). The host takes
  one exec 1 an enemy in 2 s, none while one runs, and only when its own copy is a Monster (ActorType 3) in life state 1
  holding Groggy or a marker, or with its balance at 0 after her claims of that turn. It then hands her the enemy
  without the 4 s hold or the guards, in that turn once its copy is out of NoDamageNoHit, freezes its copy although
  Groggy releases it, and holds her lethal claim (its copy at 1 HP, its hp lines at 0) and its own dead for that enemy
  until her exec 0: 6 s after her exec 1 at most, and her lethal claim 6 s after it came at most (`held-expired`). A
  marker on the host's copy of an enemy she owns gives it back to the host the same way. While a takedown runs it counts
  as its executor's hit, so a living enemy stays with them for 10 s after it unless the other player hits it. The guest
  takes an own G for a copy in her takedown even under NoDamageNoHit.
- The owner's SBE entry carries flag 8 (`kExec`) while its copy holds a marker. The drawing side then freezes its copy
  despite Groggy, follows the stream through Groggy and through the stream's dying flag, and goes back onto the stream
  at once instead of after 200 ms, so the takedown plays there with the executor's ghost. Its own copy's death still
  releases it. Nothing in the mod starts `Passive_FinishReady` (2001102), and the host refuses an exec line for a
  BossMonster. The game still applies 2001102 by itself to a boss in a Finish stance, on her copy too; the finish
  guard ([Shared bosses](#shared-bosses)) takes it off her copy and holds her killing hit on the host's boss.
- Every way back puts each copy back in this order: its replays stopped, Velocity zeroed, the movement component back
  in the manager if it was there, the speed override as it was; then the freeze comes off. The game-thread part has
  its own SEH latch: the first fault stops it for the run, and after a fault in the mod's own reads every copy is put
  back once.
- `coop fight pilot test` limits the guest's side for solo tests from a recording: `freeze` (the BlockAI effect only),
  `cmc` (the movement component out too, nothing written), `drive` (root, speed and Velocity too) or `replay` (all of
  it, the default). Each change puts every copy back once. `coop fight pilot test target` calls the force target once,
  on the first enemy this game owns, and logs its target, aggro level and detect result as they change for a second.
  `coop fight pilot test exec` empties the balance of the first frozen copy this game draws at the job's next turn
  (a stamina drop, as a hit of its EVE), so the copy goes groggy and can be taken down.

The commands, the notices and the solo test are in [usage.md](usage.md#same-place-experimental).

## Same spawns

Same spawns (`same_spawns`, experimental, the host's value, on by default, not tested in game yet) has the guest's game
hold the host's common enemies in a zone where both players stand. It builds on shared enemies: an enemy it creates
pairs through its spawn key like any other.

- Only EventSpawnTable rows that spawn on zone entry (SpawnType EnterZone), whose enemy is a Monster that shared
  enemies share (`fight_chars`, or with `auto` every Monster but the few it leaves out) and whose SaveType is None,
  ResetZone or ResetZoneWithTransform take part. Save and SaveWithTransform rows, rows that keep
  their object through a zone reset (`bResetZoneKeepObject`), and ZoneEvent and quest rows are never touched. Each
  game reads a row through the game's own lookup (`FUN_141a9db80`) and the row's zone through the ZoneTable lookup
  (`FUN_141a9b8a0`), and keeps what it read for the session. The game runs a row's lazy init (vtable slot `+0x20`)
  before its first use; in this build that slot is an empty function for both row types, so reading the rows without
  it skips nothing.
- Zones travel as ZoneTable row IDs: a zone's name is an FName, whose index differs between two processes.
- Each game counts its own epoch: one more when its current zone (logic `+0x598`) changes, when the game's spawn
  manager starts entering or resetting a zone again (its `+0x1c` goes to 1 or 2 after 3 or 4), and when 3 or more of
  its enemies come back under new GUIDs in one census (two enemies of one key are no change). The host sends `SBF13
  epoch <gen> <zone> <n>` at each change and every 5 s, so a line lost on the way stalls nothing for long, and each
  side drops a line of another epoch.
- The zone is shared while both games are in the host's zone, each settled 3 s after its last epoch began with no
  spawn pass running, and the other EVE (as its ghost stands) is within 100 m. The guest then sends her keys there as
  `SBF13 have <gen> <n> <part> <parts> <spawnId>:<idx> ...`, 24 keys a line and 10 lines at most, at once at a new
  epoch and every 5 s after. The host answers one round each 500 ms at most: `SBF13 spawn <gen> <n> <spawnId> <idx>
  <charId> <x> <y> <z> <yaw>` for each of its Monsters there she lacks within 1 km of her EVE (as her ghost stands in
  the host's world; never a dying one), where it stands in whole
  centimetres, and `SBF13 drop <gen> <n> <spawnId> <idx>` for each key of hers it lacks, 16 of each a round.
- The guest checks each line: the epoch, the shared zone, the row in her own tables and its zone, a place within 1 km of
  her EVE, no enemy of hers with that key, and 32 calls a second at most. She creates a key through the game's spawn
  function on its spawn manager (`FUN_141c1c9a0`, as `FSBCreateActor` does) and removes one through the game's despawn
  job (`FUN_141b077f0`, as a ZoneEvent despawn does): never a kill, and never an enemy that shared enemies pair. A
  created enemy that shows up as no Monster, or as another character than the host's, is removed again, within the same
  32 calls a second. One the despawn cannot find again (a dying one, for example) stays and is logged as kept. A key she
  refused counts as hers in her next list, so the host stops asking for it until the epoch moves. So does an enemy she
  killed that shared enemies did not pair (another difficulty, or past 16 pairs), since the host's enemy may still be
  alive. When its row takes part in the host's zone, the host's first drop line for such a key shows the host lacks it
  too, and the key leaves the list. A key refused as too far or for room (`full`) is left out of the list, so the host
  asks again once she is nearer or has room, and an enemy she created leaves the list once it has died or left her game.
- Both calls run inside the shared fight's job on the logic thread, under its fault latch. The spawn manager, the table
  holder and the job sender are read from their globals and never made by the mod: their getters (`FUN_141adc3d0`,
  `FUN_141a97f20`, `FUN_141a97b90`) allocate one when it is missing. The spawn call gets the spawn manager, the
  EventSpawnId, the SpawnIndex, the position, the rotation (0, yaw, 0), no extra request data and flag 0 (what the flag
  does is not known yet). `FUN_141c1c9a0` itself passes a delay of 0 to `FUN_141c1ca40`, so the key spawns at once. It
  reads the table holder through its getter, and for a row with EventOnSpawning events it sends them through the job
  sender's getter. The spawn it starts reaches `NewActor`, whose actor setup reads the reg through `FUN_141a97cb0`. So
  the guest calls it only while the holder, its tables, the job sender and the reg exist; with the spawn manager or
  one of those not made she refuses the key (`no spawn manager`) and calls nothing. The despawn call gets the job
  sender, the logic turn and the enemy's GUID, after the enemy is found again by GUID with that key and still fighting.
  While that enemy holds BattleMode (state 30) or runs a takedown marker, or either read fails, she refuses the drop
  (`busy`): the enemy stays in her list, so the host asks again and the despawn goes once she is done with it. A census
  whose list of enemies came out partial (a read that failed, or more than 256 enemies with spawn keys) does nothing,
  since an enemy missing from it would read as one the game lacks.
- The `fight=` line of `coop-status.txt` carries `spawns=off`, `on` or `stopped` (the pilot's latch stops same spawns,
  since the ghost's position no longer reaches the job), and on the guest's side `spawned=`, `despawned=` and
  `spawns_differ=`: the refusals, and the created enemies undone or kept, whose reason shows that the two games' tables
  or `fight_chars` differ (`no row`, `save-row`, `keep-row`, `event-row`, `another zone`, `row taken`, `not shared`,
  `charId`), not those of the moment (`too far`, `full`, `no spawn manager`, `not made`, `gone`, `busy`, `no such
  enemy`). Lua's notices read it.
- `coop fight spawn probe` (`fight probe spawns`) runs the same census, epoch and row reads in the probe's job on one
  game, and logs the outcome for each shared Monster once an epoch, 32 a census at most so that one hand-over's 128 log
  lines are enough. It sends no line and calls neither the spawn nor the despawn function.

The log lines are in [usage.md](usage.md#same-spawns-experimental).

### The spawn filter

Same spawns let the guest's game spawn its own enemies on each zone entry and reset, then remove the ones the host's
game lacks on its drop lines, at best 3 s after the zone settles. The spawn filter (`spawn_filter`, the guest's own,
off by default, not tested in game) has her game refuse those spawns instead. Lua adds the word `filter` to the `coop
fight on` request (and to the spawn probe's); it is a word of that request, never a line on the wire, so the protocol
stays 12.

- The keys (`SpawnGuest` in `fight/spawn_sync.h`): a key she despawned on the host's drop, a key she answered with no
  enemy of hers left (refused, or killed while not paired) that the host's drop names, and the key of each paired copy
  of hers that died on the host's `dead` line, when its row takes part in the host's zone. A copy whose fight she took
  no part in does not die there ([Achievements](#achievements)) and is not listed; the host's next drop removes it
  and lists it then. Her own lethal hit adds nothing until the host's `dead` comes, since the host may refuse it. An
  extra enemy's key has no row, so no spawn request names it, and it is never listed. A spawn line of the host's epoch
  takes its key off before her spawn runs (her own create meets the filter too). A new host epoch, a world line from
  either side and the session's end empty the list: the host's on, off or world as it comes in, and hers as it goes
  out (her fence: a load, or a census whose every enemy is new). Her own epoch moves keep it, since her resets respawn
  exactly these keys, but a reset of hers that her fence also takes as a world change runs unfiltered. Which of her
  deaths and camp rests do that is for the in-game test to show. 240 keys at most.
- After each of her steps, and before each spawn of hers, the shared fight's job publishes the list to a table of 240
  atomics (`BlockTable`, `spawnId << 8 | index` a slot), which a hook on any thread can read without a lock. A new
  session empties the table before its gate opens.
- The hook sits in one slot of the game's image: the second entry of the SpawnRequest vtable (`.rdata` `0x145c10020`,
  the vtable at `0x145c10018`), which holds `SpawnRequest::Execute` (`0x141c10a90`). RequestSpawn (`FUN_141c1ca40`)
  calls Execute directly while the slot holds it and through the slot otherwise, and the consumer of its delayed queue
  (`FUN_141c1cd20`) always calls through the slot; neither has a CFG check. One aligned 8-byte store therefore routes
  both through the hook, and no instruction byte of the game changes.
- The worker makes the swap once a run, when the gate first opens (the guest's side asked with `filter`, or the spawn
  probe), on the pinned build, before `coop off` and before any fault of the hook. It reads the slot, makes its page
  writable with `VirtualProtect`, swaps it with `InterlockedCompareExchange64` from Execute only, and puts the page's
  protection back. A slot that holds anything else (another mod's hook) is refused with a log line naming what it
  holds, and never written. At `coop off`, and after a fault of the hook, a compare-and-swap from the hook only puts
  Execute back; any other value is left. The DLL is pinned, so a thread still inside the hook after the undo returns
  into mapped code. Between sessions the hook stays and passes every request on.
- The hook takes the request. With the gate shut it calls Execute at once. With the gate open, under its own SEH latch,
  it reads the table holder (`DAT_147032510`, never through its getter `FUN_141a97f20`, which makes one when none
  exists), finds the request's EventSpawnTable row with `FUN_141a9a780(holder, 0, request + 0x28)` (the row's FName,
  the call Execute makes first), and builds the key from the row's EventSpawnId (`+0x10`) and the request's SpawnIndex
  (`+0x30`), the two values Execute passes to `NewActor`. A key in the table is counted, pushed to a 16-entry ring for
  the worker's log, and refused: the hook returns null, which every caller takes (the immediate path returns it, the
  delayed one ignores it, and SB's own spawn rule asks again later and is refused again). Any other request goes to
  Execute, which runs outside the guard, so a fault inside the game's code is never taken for the hook's. Execute reads
  RCX only, so a one-argument hook forwards all it reads.
- It refuses only EnterZone Monster rows of None and ResetZone types that the host lacks at that place, the keys same
  spawns already remove. It never kills, so nothing reaches rewards, drops, kill counters, the zone's death record or
  zone events, and ZoneEvent and Quest spawns are other rows that never reach the table. A wrong refusal heals: the
  host's next round sends `spawn` for the key, which leaves the table before her create runs.
- The first entry into a zone still spawns and removes: the guest learns what the host lacks only from its drops and
  its `dead` lines. The filter takes her later resets in that host epoch, except one that is also a world change in
  her game. Sending the host's absent keys with its epoch line would cover the first entry too; it needs a walk of the
  EventSpawn table by zone, not reverse-engineered yet.

The log lines are in [usage.md](usage.md#spawn-filter-experimental).

## Extra enemies

Extra enemies (`enemy_extra`, 0 to 3, the host's value, 0 by default, not tested in game yet) build on same spawns:
the host's game makes that many more of each common enemy where both players stand, and same spawns hand them to the
guest's game like any other key of the host's that she lacks.

- The host gives extras to a Monster that shared enemies share, of a row that same spawns reconcile (an EnterZone row
  that is no Save or keep row: the guest's save may hold that enemy dead), not dying, within 116 m of either EVE (so
  its farthest extra stands within 120 m), while the zone is shared. Bosses and Alpha Naytibas are BossMonsters
  (ActorType 4), so they get none, and neither do the four Monsters the CharacterTable ranks Boss or Elite: M_Gorgon
  (50330), M_RoyalGuardFemale (50500) and its WLA_ and WLB_ variants (45050001, 55050001). An enemy gets its extras
  once a life: after a respawn under a new GUID it gets new ones. Extras are made only while the shared Monsters within
  120 m of either EVE, counted with the host's extras and the new ones, stay at 16 or fewer, the most stage 1 can
  pair.
- An extra's key is EventSpawnId `0xE0000000 | n << 8 | slot` and SpawnIndex `slot`, where n counts the enemies given
  extras since the game started (a new session goes on counting, so a dying extra of the last one never shares a key
  with a new one) and slot runs from 1 to 3. No EventSpawnTable row of this build is in that range (its highest
  EventSpawnId is `0xD42B5F51`). The host checks once a session that its tables hold no row at the first key,
  `0xE0000101`; if they do, extras stay off for the session. The game's death path skips the respawn and the zone
  bookkeeping for an actor whose key has no row; that a save never holds one is still to be checked in game.
- Slot s stands 100 + 100 s cm from its enemy (2, 3 or 4 m), 120 degrees apart around the enemy's yaw, at the
  enemy's height and facing its way. The game's `NewActor` (`FUN_141ad1290`) makes it, with the arguments
  `SpawnRequest::Execute` passes: the logic singleton, the charId, the position, the rotation (0, yaw, 0), not a
  player (0, 0), the key, 0 for the row field, 0, 1, no request extra data, 0, flag 0 (no actor replaced) and 0. The
  request extra data is null because the game's FSBActor creation (`FUN_141ca9100`) checks it for null and then keeps
  the same default a fresh request would copy in.
- Same spawns count an extra's key as part of the shared zone without a row: the host sends `spawn` for one she lacks
  and `drop` for one of hers it lacks. She makes the key through `NewActor` too, with the charId of the host's line,
  and refuses it (`row taken`) when her own tables hold a row at that key, or (`no such enemy`) when no Monster of
  hers that shared enemies share has that charId: the host makes extras of common enemies only, so any other charId
  would be a character the host picked freely. A key refused as `no such enemy` or `full` is left out of her list, so
  the host sends it again: an extra's own enemy can come in the same answer and only show in her next census. Stage 1
  then pairs the two copies by key.
- Each game keeps the extras it made in its capture list, 48 at most. One that left the map (killed, despawned) is
  forgotten at the next census. The host despawns one still fighting more than 120 m from both EVEs. At the session's
  end every extra still fighting is despawned in each game, and a dying one is left to its death. The host's extras
  also go when her shared enemies stop (her off line) or her lines are ignored, and hers when the host's same spawns
  stop on her side (its off or world line). Every despawn goes through the game's despawn
  job (`FUN_141b077f0`), never a kill.
- `NewActor` runs inside the shared fight's job on the logic thread, under its fault latch, only while the table
  holder, the world's actor manager, the job sender and the reg exist: `NewActor` and its actor setup
  (`FUN_141ba6d20`) read them through getters that would make them (the job sender's `FUN_141a97b90` and the reg's
  `FUN_141a97cb0` for the last two). An extra whose GUID cannot be read right after `NewActor` stops the shared fight
  for the run and is logged as kept, since no capture can take it off.

The log lines are in [usage.md](usage.md#extra-enemies-experimental).

## Shared bosses

Shared bosses (`bosses`, experimental, the host's value, on by default, not tested in game yet) add the bosses and
Alpha Naytibas (the game's BossMonster type, ActorType 4) to the pairs of shared enemies. A boss takes a place before
any common enemy, its maximum HP takes the host's `boss_hp_scale`, and with same place on its AI stays in the host's
game. The host sends `SBF13 bosses <gen> <percent>` with its list.

With same place on, the guest's copy of a boss is frozen and never casts a skill, so on its own it would never enter
battle mode, change phase or summon anything. The host's job reads them on its own copy and tells her game, which
applies them to her copy:

- The host reads its boss's battle mode (FSBActor `+0xb58`) and sends `SBF13 bstart <gen> <hguid>` when it turns on,
  then every second while it stays on. The guest calls the game's SetBattleMode wrapper (`FUN_141a7cd30`) on her copy,
  once while the copy stays in battle mode, with the arguments of the game's own `FSBActor::AddTargetedByEnemy`: on,
  then `0, 0, 0, 1`. The fifth argument, 0, runs the boss's `EventOnBattle` (mostly the arena walls), and the call runs
  `EventFirstTimeOnBattle` once. Called from the logic thread, the game queues it for its game thread. She calls it only
  for a copy her game draws as a BossMonster in life state 1, with the job sender and the reg already made (the call
  reads both through getters that would make them), and only while her EVE is within 30 m of her copy or its last
  player ([Achievements](#achievements)). A refused bstart is taken at the host's next repeat. Her game takes
  the copy out of battle mode through the same wrapper with off, then `0, 0, 1, 1`, the arguments of the game's own
  battle-off calls: when the host's lines bring no bstart for 10 s (the host's boss left battle mode; a gap of over 2 s
  with no line from the host, as while the host's game is paused, is not counted), when her game stops drawing the copy
  (the pair ends, same place stops) and when the session ends (`coop fight off`, the link, the fault latch). A dying
  copy gets no call. The host's next bstart for that copy calls it again.
- The host reads its boss's effect list and keeps the rows of that boss's allowlist, a table built from the game's
  tables for build 24463856: its phase rows and their FX rows that a skill applies, and its MinimumHP rows (the phase
  thresholds, and `MinimumHP_Dispel` 1001323). It sends them in list order as `SBF13 phase <gen> <hguid> <oe>
  <id,id,...|->` when they change and every second in battle mode. The guest refuses a line with an ID her own table
  does not hold for that boss (a bad line), of another owner epoch, or for a copy her game does not draw. Through the
  game's effect call (`FUN_141ad08b0`), her copy its own caster as for the boss's own skill step, she applies each row
  that came into the host's set since her last line for that copy, in the host's order, a dispel row first (the host's
  copy holds a row next to the dispel that would end it only when that row started later). On her first line for a
  copy, and on the line after the game refused one of her rows, she compares the set with her copy's effect list
  instead: each row the copy lacks has come, and each row of the allowlist it holds that the set lacks has left. Before
  them she applies `MinimumHP_Dispel` when a threshold left the set and none came in, and the boss's phase dispel row
  (Crawler 5022094, SkullJuggernaut 5015002) when a phase row left and none came in. The phase row's own stance change
  does the rest on her copy. 19 bosses have a row in the table; the other BossMonsters (the
  Alpha Naytibas, challenge and variant rows) get bstart lines only.
- At each census the host looks for actors with no spawn key whose owner (logic actor `+0x400`) is a boss it shares,
  and finds the SummonActor row that made each one in the owner's effect list, by the effect GUID at `+0x40c` (an
  effect's GUID is at its `+0x20`). Marionette's DollHeads and Maelstrom's BodyBags have rows in the table. The reward
  dummies and the Elder's dummy have none and stay in the host's game. A summon gets a key in the summon range,
  EventSpawnId `0xF0000000 | n` and SpawnIndex 0, where n counts the summons since the game started, and joins the
  shared list under it. After its up the host sends `SBF13 spawn <gen> <n> <key> 0 <charId> <x> <y> <z> <yaw> <owner
  hguid> <row>`, with epoch 1 when same spawns do not run, and sends it again every second while it follows the
  summon: her game takes a repeat as one it has, and a line it refused for a passing reason (its boss not paired yet)
  can go through later. The guest makes it through `NewActor`, as for extra enemies,
  with that key where the host's stands: only within 1 km of her EVE, for an owner she pairs as a BossMonster, and for a
  row of her table that makes that charId. She then applies the row's effects through the effect call (its Start row,
  which holds the summon still for a moment, and its Check row), and the pair forms on the key; same place freezes and
  drives it like any other copy. If the game refuses one of those effects, she despawns the summon at once: without
  them her hits would take far more HP than the host's copy loses. A summon of hers that no pair holds 3 s after she
  made it is despawned too, and so is every one still fighting when the session ends. A key she despawned for either
  reason is not made again until the next on, off or world line of either game. She holds 32 at most at once.
- A Finish stance (HP under 2) applies `Passive_DeathReady` (2001101), which chains `Passive_FinishReady` (2001102, the
  state the finisher needs). In each turn a paired boss copy of hers holds either one, her game applies
  `FinishReady_Dispel` (2001103) and then the boss's own `Passive_Immortal` (2001100) again: her hits stop at 1 HP and
  no finisher starts on her side. On the host's side, her claim that would kill a boss whose copy holds either row takes
  it down to 1 HP and kills nothing, however long the stance lasts (`fight finish-held`). So a boss in its Finish stance
  ends only by the host's finisher; a boss without one dies of her killing hit, unless its own thresholds or Immortal
  hold it. When the host's `dead` comes for a boss whose fight she took part in, her game applies `MinimumHP_Dispel`
  and `FinishReady_Dispel` to her copy before the kill, so neither a threshold nor Immortal holds it. When the pair
  ends any other way (the host's `dead` for a fight she was not in, the host's `down` or world line, the link,
  `coop fight off`, the fault latch), her game applies `FinishReady_Dispel` to a guarded copy still under 2 HP, so the
  Immortal it put back goes and her own hit ends that boss in her game.
- Every call runs inside the shared fight's job on the logic thread, under its fault latch. The host's side makes no
  new game call: it reads, and her claims go through ApplyStat as before. Recordings keep none of these lines.

The log lines are in [troubleshooting.md](troubleshooting.md#a-shared-boss-differs-between-the-two-games).

## Shared quests

Shared quests (`shared_quests`, experimental, off by default, not tested in game yet) move the guest's quests to the
host's state through the game's own quest functions, one step at a time, for the steps the two players make together.
`quest/sync.h` holds the line format, the quest table and each side's rules; `quest/engine.h` holds the reads and calls
on the game's quest data and the worker's side.

The game's quest manager runs on the game thread, so the mod's pass does too: every 250 ms `coop_tick` reads the local
player's quest unit (the quest manager at `0x147032588`, its unit from `FUN_141c5e880`) under the shared quests' own SEH
latch. The pass walks the unit's three quest arrays (in progress, complete, failed) and its ID map, and for each shared
quest reads its state, its active group and the state of each task the game made for it. Before each pass and each call
it checks that it is not on the game's logic worker thread (whose ID the game keeps at `0x1470634f0`) and that the save
is still the co-op save it started on: another save ends the side with `SBQ13 off slot` (the worker starts a new one
on the next co-op save), while a load (the title screen, a map change) only pauses it.

- The host only reads. Each quest whose state changed goes to the guest as one reliable line on channel 2 with the
  whole state, numbered per quest, so a repeated or late line changes nothing: `SBQ13 q <gen> <seq> <id> <state>
  <acquire mark> <finished groups> <tasks done> <done mark>`. A group or a task is named by its place (container and
  position), which the game builds the same on both PCs from the same tables.
- Each step carries a mark that says where it may be made: `-` anywhere (no zone event, or only quest, item, UI or
  hint events), `t` in the zones the game's tables give for its events (spawns, despawns, environment changes, scenes),
  `z<n>` in the zone where the host stood when its pass saw the step (for the 38 steps the tables cannot place), `?`
  for such a step the host's pass did not see, `K` for a kill task and `#` for a quest the host denies. The table that
  gives each step's class, zones and events is built into `quest/sync.h` from the tables of build 24463856; another
  game build needs it built again.
- The guest's pass compares each host line with her own quest and plans the next forward step: an Epic or Sub quest
  she lacks is acquired by ID (`FUN_141c5cf20`, the call a quest zone event makes), a Request on her board is accepted
  with the board's own call (the Request quest's vtable `+0x10`), and a task is completed through its own Complete
  (task vtable `+0x60`). There is no quest-complete call: an Epic or Sub quest completes inside its last task's
  Complete, with its reward and next quest, and a Request stops ready to hand in, as in solo play.
- Each call has its guards, read again just before it: a task only at state 1 in her active group, whose parent is
  that group and whose Complete slot is one of the game's two Complete functions; an acquire only for an ID her quest
  map does not hold (the game refuses any other too, and after each load the pass checks that every complete and failed
  quest is in that map before it acquires anything); a Request accept only at state 0 on a Request her board accepts.
  A step the game refuses leaves that quest alone for the session. At most one step goes per pass.
- A step is the guest's only when she stood in the host's zone when its line came and her quest stood where the host's
  stood before the step. A quest the host moved without her is behind: nothing of it is planned, a forced step
  included, until her own play brings it to the host's state.
- The guest sends display lines only: `at` (her zone), `have`, `wait <why>` and `ahead`. The host applies nothing from
  them.
- When the guest's side comes on, the host sends a snapshot (`snap`, the `zone` and `q` lines, then `end` with their
  count and an FNV-1a digest) of the quests it moved while linked with that friend. It sends a new one after its own
  load, and when one of its quests goes back (an older save).

The record beside each co-op slot (`StellarCoopQuests0N.txt` in the account's save folder) keeps, per friend, the
host's marks (`h` lines) and the host lines the guest's game took (`g` lines). The worker writes it through the same
name check as the co-op copies, at most once a second and only on a change, as a temporary file renamed over the old
one. A bad line only loses that quest's marks; her live quests always decide what is made.

## Following the host

The guest's travel to the host (`session/travel.lua`, the camps lines, `game/travel.h` and the native call) moves only
the guest's EVE, through the game's own fast travel, and changes nothing in the host's game. It has not been tested in
game yet. In this version it never travels: the mod cannot yet read which camps the guest's save has activated (see
below).

- The guest's Lua sends `camps? <id>` when she presses F7 (`follow_key`) or types `coop travel host`, and with
  `follow_host=always` 5 s after the host arrived somewhere new. It sends one at most each 2.5 s.
- The host's Lua answers from the game's spawn points on its map: those named after one of the travel camps of its
  world, read once a map, sorted by distance to the host's EVE. The answer names the world and the 8 nearest, or
  `none` with `title`, `loading`, `nocamp` or `busy` (a warp or respawn of the host's under way).
- The travel camps are the 120 ZoneCampTable rows of type FullCamp, SimplyCamp, PhoneBooth or Tetrapod that lead to
  exactly one story world in build 24463856. Autosave volumes, camps that lead to several worlds or none, and the camps
  of the developer test worlds are left out. The guest's game uses a camp of the answer only if it is in her own table
  under the host's world, her save has activated it, and it already exists as a name in her game (`FName` with
  `FNAME_Find`, which never makes one).
- Her Lua checks its guards again, then hands the camp's name to the native part. On the game thread, the native part
  builds the game's 0x60-byte camp request as the game's ReturnToCamp job does and calls the game's fast travel
  (`0x141cdd7b0`), out of line under its own SEH latch. Before the call it reads the globals that the call's getters
  reach, the client's flow and phase, any warp or respawn in flight, and whether the local player's EVE is in the
  world. It makes at most 3 calls in 10 s and none for 10 s after an accepted one.
- A return of 0 is the game's refusal, and the guest's Lua tries the next camp of the answer.
- The game's fast travel does not check whether her save has activated the camp (`game/travel.h`), and activating a camp
  counts toward the game's camp achievements (`Trophy_Activate_AllCamp` and the camp rows of AchievementTable). Her Lua
  therefore takes only a camp that a read of her save's activated camps confirms. That read does not exist yet, so
  every travel is refused before `camps?` is sent (`travel refused: no read of the camps this save has activated` in
  `UE4SS.log`, and the failed notice), and no offer shows.
- After an accepted call, the native part reads the game's warp block every 250 ms: `pending`, `warping`, `arrived`,
  or `refused:stuck` when the warp has not started 10 s after the call. `coop status` shows it as `travel=` on the
  engine line, and `coop-link.log` has one line per call and per state.
- The guards, read before the request and again before each call: a guest in a session, on a co-op save, her EVE
  alive, no warp or respawn under way, the game not paused and not in photo mode or a menu, no Night Operation run, no
  cutscene in her game, and while shared enemies run no boss fight and no enemy in battle within 30 m on her side (the
  `fight=` line's `boss=` and `battle=`), and 10 s since the last accepted travel.

## A player down

Each game reads its own EVE's life state with its vitals (`life=` in `coop status`) and the friend's from her vit line:
down in life state 3 to 5 or at 0 HP, alive in 1 or 6, unknown in any other state or when no vit line came for 3 s. The
native worker hands the friend's state to the shared fight's job as a local message, on each change and once a second.
It never goes on the wire.

- On the host, while the guest's EVE is down, each same-place pair she owns comes back to the host at the next turn,
  guards or not, if the enemy stands within 30 m of the host's EVE, and stays his while she is down. While the host's
  EVE is down and hers is alive, his common pairs within 30 m of her ghost go to her once the 4 s hold and the busy
  guards allow it. Bosses stay the host's. An unknown state changes nothing, and `aggro=host` keeps every pair with the
  host. Each of these hand-overs writes one log line.
- The 30 m limit is there for achievements: the game that takes an enemy forces its target onto its own EVE, which makes
  that EVE the enemy's last player, and a kill counts for its last player from any distance. A pair already where the
  down rule puts it stays there, so nothing is handed to the down EVE.
- While the host's EVE is down, the host drops the guest's claims on boss pairs. Their numbers are still acknowledged,
  so her copy's HP goes back to the host's. The host's respawn resets the boss in his world and her copy follows, as a
  death ends a boss fight in solo play.
- A down EVE takes no part in a kill through the 30 m clause (see [Achievements](#achievements)).

### Revive

The revive runs on the downed player's side (`session/group.lua`, every 250 ms) and sends nothing: her game reads its
own state, the friend's vitals and the friend's ghost. The friend's game calls nothing.

- These conditions must hold for 3 s with no gap: the downed player's `revive=on`; her life state 3 and the death
  screen's animation playing (the lookup Night Operation's solo run uses, in `core/unreal.lua`); `warp=idle` on the
  engine line (no respawn or warp in flight, read by the native part on the game thread); the friend linked, with vitals
  alive; the friend's ghost on her map within 2 m across and 1 m up or down of her EVE's mesh; `boss=0` on the
  `fight=` line (shared enemies running and no boss fight on her side, the 10 s after a host's `bstart` included); a
  standalone game (`KismetSystemLibrary::IsStandalone`, since in net mode 3 the call would go to a server); and no
  Night Operation probe rule set (with one, the respawn would spend a life count).
- Her game then calls `ServerRequest_ActorRespawn(<her EVE's id>, false)` on her player controller: the game's in-place
  respawn, with no camp warp and no zone reset. The game refills the recovery items as at a camp respawn. If her life
  state has not moved 2 s later and every condition holds again, `ServerRequest_ActorRevival` follows once. One call
  per death.
- A death screen that still plays over a living EVE is hidden, as Survival Protocol hides it, and shown again at the
  next death, at the end of the session, when the revive turns off for the run and at `coop off`.
- The log gives one `revive result` line: the life state, HP and death screen before and after, and whether the EVE
  pawn is the same.
- The friend's game shows its notices from her vitals: `<name> is down. Stand next to them for 3 s to revive them.`
  once per death, while the friend's own EVE is alive, on her map and outside a boss fight; and `You revived <name>.`
  when her vitals turn alive while the friend's EVE stands within 3 m of her ghost.
- `coop revive test` makes the same call alone, at the death screen of a co-op save outside a session, for the first
  in-game check.
- With both players down, nobody can revive. Each respawns at a camp in their own game, each world resets on its own,
  and same spawns brings the guest's enemies back to the host's set.

## Camp rests in a shared area

Either player may rest. Nothing blocks the guest's rest, since a block would need a hook on the camp interaction. A
rest resets only the resting player's own game.

- The host's rest resets his zone. Same spawns sees the spawn manager's reset states and moves its epoch, and the
  guest's game follows the host's enemy set: full HP and the host's positions for her pairs, and the rows of his that
  she lacks created on her side.
- The guest's rest heals her and resets her own game. In the zone she shares with the host (his epoch line's zone,
  his ghost within 100 m), same spawns then removes again each enemy she respawned that the host's game lacks, so her
  rest brings no enemy back there. Elsewhere, or with same spawns off, her rest is the game's own.
- The guest's Lua reads `epoch=<zone>/<n>/<resets>` on the `fight=` line. The host's `n` moving in the same zone,
  while his vitals read alive and he was not down in the last 10 s, gives
  `Enemies are back: the area reset in <host>'s game.` Her own `resets` moving while same spawns run, after her EVE
  was alive for 10 s, gives `Shared area: only <host>'s camp rest brings its enemies back.` On the guest a reset counts
  only in the host's zone while his ghost stands within 100 m. A respawn after a death gives neither notice.

## Cutscene wait

Each game looks once a second, while linked, for the game's theater observers (`SBTheaterLevelSequenceObserver`). A
cutscene plays while one of them has a valid sequence player whose `IsPlaying()` is true. Finding the observers walks
every object (25 to 80 ms on the game thread), so the walk runs only while a level sequence actor plays (those actors
come from the engine's class hash, a fraction of a millisecond), and the observer found is kept while it plays. Up to
0.6.0-beta.1 the walk ran every second while linked, a frozen frame each second. The log says
`cutscene on: <sequence>` and `cutscene off`. The player controller's cinematic flag is not in this build's reflection
data, so Lua cannot read it.

While a cutscene plays in the host's game and its own photo state is `0`, the host's Lua writes `c` as its photo state,
and its photo line carries `c`. The guest's Lua writes `cut=1` in `coop-state.txt` while her `cutscene_wait` is on and
the host's ghost is on her map. Her native part then holds the photo sync pause for that `c`, with the photo pause's
release rules and `photo_freeze_max`; `photo_sync` plays no part in it. The native part shows no notice for it, and her
Lua shows one in her language, once per pause. A cutscene in the guest's game pauses nothing on the host's side.
Whether every story scene, dialogue and boss intro runs through a theater observer has not been checked in game yet.

## Doro races

A Doro race runs in Lua: `race/run.lua` on the game side, `race/model.lua` for the rules and the race lines,
`race/doro.lua` for the Doros, `race/drive.lua` and `race/drive_model.lua` for the driving. Its only SB calls are two
reads on EVE, `IsSprint` and `GetSBSpeedForAnimGraph` (for a log line); the rest are engine functions. The native
part only carries the race lines. The commands and rules are in [usage.md](usage.md#doro-races).

### The display Doro

Each Doro the mod shows is a plain `Actor` that Lua spawns, with one `SkeletalMeshComponent` that holds Doro's mesh
(`CH_NPC_Dororong`, at the game's own scale of 1.5, about 59 cm tall) and collision off. It is not an SB character: it
has no row in the game's tables, no AI and nothing that can die. Doro's own animation Blueprint is never used. The
component runs the engine's single-node animation (`SetAnimationMode(1)`), and each frame Lua picks what it plays with
`PlayAnimation`, `SetBlendSpaceInput`, `SetPlayRate` and `SetPosition`:

- On the ground, the two-legged blend space `IdleRun_BS_Peaceful_2`, with the speed as its input up to 500 cm/s (EVE's
  run) and played faster above that, up to 1.8 times. The speed is smoothed over about 0.1 s.
- On all fours (`IdleRun_BS_Peaceful_1`) while EVE sprints, and for 0.3 s after.
- In a jump, `N_Dororong_Evade`: its first 0.5 s at take-off, its frame at 0.5 s held while she is in the air (play
  rate 0, the position set without firing notifies), and the rest, from 0.5 to 1.07 s, at landing.
- At the results, while the racer stands (under 50 cm/s): `N_Dororong_Evade` in a loop for the winner and
  `N_Dororong_Exhaust` for the other racer.
- While the race drives (see [Driving](#driving)): on all fours from 60% of the top speed and back on two legs under
  55%, played up to 3 times faster, and `N_Dororong_Exhaust_Evade` at twice its speed for the 0.6 s of a stumble. The
  Doro also leans into a bend by the speed times the turn rate of its yaw (25 degrees at 1 g, at most 25, smoothed
  over 0.15 s) and dips its nose at a landing by a degree for each 50 cm/s of landing speed (at most 15), on a 6 Hz
  spring. The lean is the rotator's `Pitch` and the nose its `Roll`, since the mesh faces its +Y; both signs are
  unchecked in game.

The mesh and the clips come from the game's own files (`StaticFindObject`, else `LoadAsset`). The engine's garbage
collector unloads an asset that nothing in the engine references, and a reference held in Lua does not count. In
0.5.0-beta.1, a clip that no Doro had played for a while was unloaded, and the next `PlayAnimation` loaded it again
synchronously: 5 loads a minute taking 185 ms in all while EVE sprinted, each one a short freeze in game. Each Doro
now carries one keeper per clip: a second `SkeletalMeshComponent` with Doro's mesh, in single-node mode, given the clip
with `SetAnimation`. Its animation instance holds the clip through `CurrentAsset`, which the collector follows, so every
clip stays loaded while any Doro stands. The keepers are not attached and never move. They have `bVisible` off, so the
renderer never gets them, component tick off, `VisibilityBasedAnimTickOption` 3 (pose only while drawn) and collision
off. They go with their Doro's actor; on the ghost, whose actor stays, they go when Doro mode ends. A clip that is not
in memory is loaded when a Doro is made, not during the race.

A race shows at most two Doros of its own: before GO one at the start line's centre, and during the race one at the next
checkpoint and one at the one after it, facing the checkpoint before them. Their object paths stay in
`coop-race-doros.txt` while they stand, so a Lua reload (Ctrl+R) in a race destroys them at its first tick.

### The Doro look

The look draws your EVE as a Doro. Its Doro is placed each frame, after the native tick, at the world location and
rotation of EVE's main mesh (her feet); it is not attached to her. The look and the race's driving (below) are the
features that write to the player actor. The look writes two things on her, and hides the drone:

- `bHiddenInGame` on each of EVE's mesh components that did not have it, through `SetHiddenInGame`. The game shows and
  hides her parts (a drawn blade) with `SetVisibility`, which sets the separate `bVisible` flag, so the look neither
  fights those changes nor undoes them. `SetActorHiddenInGame` on EVE is not used.
- `VisibilityBasedAnimTickOption` on her main mesh, set to 0 (always tick the pose). EVE's Blueprint ticks her pose
  only while she is drawn, so a hidden EVE would stop her pose, her animation notifies and the root-motion moves of
  dodges and ledges.
- The drone that follows EVE is an SB character of its own, so hiding EVE's parts left it flying beside the Doro. The
  look sets `bHiddenInGame` on the drone's main mesh (`CharacterMesh0`) through `SetHiddenInGame`, only when the mesh
  does not have it, and writes nothing else on the drone. The actor itself stays shown: hiding it would also turn off
  its spot light, which lights EVE's way in dark places, and its guide ray and wait signal. The look finds the drone
  with one `FindAllOf('CH_Drone_BP_C')`, the drone's Blueprint class: the nearest one of exactly that class within 30 m
  of EVE, whether the game shows it or not. `FindAllOf` walks every object on the game thread (25 to 40 ms in game), so
  it runs at look on and once more each time the drone the look holds goes, and never on a timer. If it finds none, it
  does not look again until the next look on. Once a second the look checks the held drone's mesh, and hides it if the
  game showed it. A mesh the game hid is left alone until the game shows it. The log says
  `[StellarCoop][DR] look drone hid <name> at <m> m` when it hides the drone the first time,
  `[StellarCoop][DR] look drone <name> at <m> m hidden by the game: hidden when it shows` when the game had hidden it,
  or `[StellarCoop][DR] look drone none within 30 m (<n> in the world)`.

Before it changes anything, the look writes `coop-look.txt`: EVE's object path, the old tick option, its Doro's path and
the names of the parts it hides. Before it hides the drone's mesh the first time, it writes the file again with the
drone's object path added at the end. Every 250 ms it checks that the same EVE is on the same map (otherwise it turns
off), hides again any listed part the game showed, and sets the tick option back to 0. Once a second it hides the drone
again if the game showed it. The log names each flag change the game made
(`[StellarCoop][DR] flag <part> visible=<0|1> hidden=<0|1>`) and gives the counts once a minute:

```
[StellarCoop][DR] look hid=<n> tick=<t>->0 rehid=<n>/min retick=<n>/min reload=<n>/min reload_ms=<ms>
```

`rehid` counts the parts and the drone hidden again, `retick` the tick option set back, and `reload` the Doro assets
loaded again after the collector unloaded them, with the total time those loads took in `reload_ms`. The loads at the
making of the look's own Doro are not counted: the counter starts at 0 once that Doro stands. Its keepers (see
[The display Doro](#the-display-doro)) then hold every clip, so `reload` reads 0 for the whole look.

Turning the look off destroys its Doro, clears `bHiddenInGame` on the listed parts only, puts the tick option back,
clears it on the drone's mesh if the look hid that mesh, the drone is still there and the mesh still has it, and deletes
the file. That runs at the race's end, on `coop race look off` and `coop off`, after a map change and at the look's
first error, after which the look stays off until the mod reloads. If one of those steps fails, the file stays. A Lua
load that finds `coop-look.txt` (after Ctrl+R, or a Lua state that stopped) uses it at its first game-thread tick: it
destroys the Doro named there if that actor still shows Doro's mesh, clears `bHiddenInGame` on the listed parts that
still have it, puts the tick option back, clears `bHiddenInGame` on the main mesh of the drone named there if the object
at that path is still an SB character and its mesh still has it, and deletes the file. The log says
`[StellarCoop][DR] look restored <n> parts from coop-look.txt`, with `and the drone` after `parts` when it showed the
drone.

The capture is unchanged, and it counts a part with `bHiddenInGame` as hidden. While the look is on, your friend's game
therefore receives every part of your EVE as hidden, and draws your ghost with no body unless its Doro mode is on.
After the look ends, the next capture pass (once a second) publishes the parts as shown again.

### The ghost's Doro mode

Your friend's ghost is drawn as a Doro while their game takes part in the race: on the host's PC from the guest's
`have` line, on the guest's PC once the host's track has arrived and passed the checks, until the race closes. A guest
whose game answers `have <id> no <why>` stays EVE on both screens.

In Doro mode, `partner/puppet.lua` hides every part of the ghost and hangs one more `SkeletalMeshComponent`, with Doro's
mesh, on the ghost's main mesh, where her feet are, and adds the Doro's keepers to the ghost's actor. A ghost built in
Doro mode resolves Doro's mesh and each clip in a build step of its own, so no frame loads more than one. The ghost is
the mod's own actor, so nothing of the game's is touched. The Doro's speed and vertical speed come from the ghost's feet
between poses, measured over 50 ms at least. The pose stream has no sprint or falling flag, so the Doro goes on all
fours above 560 cm/s and back on two legs below 520 cm/s, and a vertical speed over 400 cm/s, up or down, counts as
being in the air. The ghost's own hiding (no pose for 1 s, another map) covers the Doro too. A Doro that cannot be made
leaves the ghost drawn as EVE, with the reason in the log. The pose stream is the same during a race: the bones still
arrive and are written into the hidden parts. While the race drives, the ghost's Doro follows the same driving rules as
yours, with the turn rate taken from the ghost's yaw in the pose stream, and its lean and nose set as a relative
rotation on the ghost's main mesh.

### Driving

From GO until our own result, `race/drive.lua` drives EVE with `race/drive_model.lua`'s car model. The model holds a
heading and a horizontal velocity. Each frame it turns the heading toward the stick's world direction
(`GetLastMovementInputVector`) at a rate that falls with speed, adds speed along the heading with a throttle that fades
near the top speed, and decays the speed across the heading by a grip, which drops during a drift (the drift keys, read
with the player controller's `IsInputKeyDown`, or hard steering at speed).

In SB's movement component, the turn of the velocity toward the stick is the engine's friction step in `CalcVelocity`,
with `GroundFriction` as the friction. SB's own speed fields (`MaxRunSpeedOverride` and the sprint scales) only set the
top speed. With `MaxAcceleration`, `GroundFriction`, `BrakingDecelerationWalking` and `BrakingFrictionFactor` at 0,
`CalcVelocity` neither accelerates, brakes nor turns the velocity, and the component moves EVE with the velocity it has.
Each frame the race gives it the model's velocity: by default through `AddImpulse` with the difference from
`GetVelocity()` and a vertical part of 0, or through a write of its `Velocity`. Before each impulse,
`ClearAccumulatedForces` drops any impulse an earlier frame left unused. In photo mode with `photo_pause=scenery` the
world's time runs while SB's logic stands still; if her movement stands still with it, the impulses would otherwise add
up. The next frame starts from the velocity the component made of it, so walls, slopes and landings act on the model.
The yaw goes to EVE with `K2_SetActorRotation`, and the pose stream carries it to your friend. The driving runs each
frame before the native tick, so the pose it captures and the Doro look both have the yaw written that frame.

On the ground SB's walking step ends by setting `Velocity.Z` to 0 (the engine's `MaintainHorizontalGroundVelocity`), so
the model takes EVE's vertical speed from her height between frames. Over a crest (on the ground at over 900 cm/s, a
climb held two frames that drops by more than 250 cm/s in one), the race calls `LaunchCharacter` with the climb's
vertical speed instead of giving a velocity.

The model steps by EVE's world time (`GetGameTimeSinceCreation`): when it has not moved since the last frame (the
pause menu), nothing is written, since impulses would pile up. Under root motion (`IsPlayingRootMotion`: a dodge) the
model holds and writes nothing, and starts again from her yaw and velocity. Every 250 ms the race sets back to 0 any of
the four values the game wrote (a stance change).

Before the four values change, `coop-drive.txt` gets EVE's object path and their old values. Our result, a quit, a DNF,
`coop off`, a map change and the race's first error write them back, on that EVE only while she is still the object they
came from, and delete the file. A Lua load that finds the file writes the values back at its first tick, even with
`coop off` still in force. No SB code found writes `MaxAcceleration` or `GroundFriction`, so the values from before the
race are the ones to put back; the 250 ms check catches a write the search missed.

### Race lines

The host owns a race. Its game sends the track and the start, each game times its own racer from its own GO, and the
host's game sends the ranking. The guest's game checks each line against fixed bounds before using it, and sends only
its own racer's lines. Each line travels as `SBC13 race <text>` on channel 0 (see [Channel 0: text](#channel-0-text)),
with whole numbers only, in centimetres and milliseconds. `<id>` is the host's race number:

| Line | From | Meaning |
| --- | --- | --- |
| `track <id> <n> <laps> <x> <y> <z> <yaw> <map>` | host | A race is armed on that start line and map; `n` checkpoints follow |
| `cps <id> <first> <x> <y> <z> <r> ...` | host | Up to 12 checkpoints from the `first`th one, so a line stays under 512 bytes |
| `drive <id> <top> <accel> <brake> <coast> <grip> <drift_grip> <turn_slow> <turn_fast> <drift_angle>` | host | The driving values both players race with, after the `cps` lines; the guest clamps each to its range |
| `have <id> <sum>` or `have <id> no map\|track\|save` | guest | The track and the driving values arrived and passed the checks (`sum`: all their numbers added, modulo 2^32), or why the guest stays out |
| `ready <id> 0\|1` | both | Out of or in the start slot |
| `go <id> <ms>` or `abort <id> <why>` | host | The countdown's length (4000), or the race cancelled (`false_start`: the ready check again) |
| `cp <id> <lap> <i> <ms>` | both | A checkpoint passed, with the race time |
| `fin <id> <ms> <flags>` or `dnf <id> <why>` | both | Your finish time and flags (1 fast run, 2 paused), or why you did not finish (`teleport`, `map`, `quit`, `left`, `late`, `time`) |
| `rank <id> <host ms or -> <guest ms or ->` | host | The final ranking |
| `end <id>` | host | The race closed |

The guest's game refuses a track with fewer than 2 or more than 64 checkpoints, `|x|` or `|y|` over 2,000,000,
`|z|` over 500,000, a radius outside 300 to 3000, a time over 3,600,000 ms, or another map than its own. A line that
fails a check is dropped and counted. A track whose `drive` line does not follow its last `cps` line is refused with
`have <id> no track`. The guest's countdown starts when `go` arrives, less half the round trip of the link's pings. A host that gets no `have` line within 10 s sends `abort <id> track` and races alone.

In `coop loopback` with no friend linked, the host's lines come back as the friend's. A second, guest instance of the
race model answers them, run on the loopback ghost's feet, and its lines go straight to the host's.

Each PC logs a `[StellarCoop][DR] result` line per race that reaches its results there, with the race's length by
`os.clock` and by `os.time`. The race clock is `os.clock`, and the two values show whether it counts wall time on that
PC.

A race calls no achievement, reward, item, quest or save function and no console command, and the only class it spawns
is `/Script/Engine.Actor`. `tests/lua/race/run_test.lua` checks both in `race/doro.lua`, `race/model.lua`,
`race/run.lua`, `race/drive.lua` and `race/drive_model.lua`.

## The cut Lion

`coop lion` spawns the cut Naytiba 02, the Lion, as an enemy to fight (plan A of the Lion study). In its first test
(0.6.0-beta.1) it spawned, moved and hit EVE, but stayed in its idle pose. Its assets ship in
`/Game/Art/Character/Monster/CH_M_NA_02/`: the blueprint `CH_M_NA_02_BluePrint_Large`, the mesh with its fur cloth, 138
animations on the Behemoth's skeleton (`CH_M_NA_46_Skeleton`), hit and attack collision data and 41 Shows. No table row
names it. Four files do the work: `cut/lion.lua` (Lua), `cut/lion_rows.lua` (the rows as Lua reads them back),
`lion/rows.h` (the rows and their build, free of Windows, tested on the build machine) and `glue/tick/lion_game.inc`
(the game's calls).

### The rows

The native part adds 237 rows to 14 tables: 222 are the Lion's own, and before them come 4 for the cut stimpacks of the
Night Operation shop (see [The cut stimpacks](#the-cut-stimpacks)) and 11 for EVE's cut Tachy Mode ChainSpin (see
[The cut ChainSpin](#the-cut-chainspin)). A generator kept outside the repository writes
every field of the Lion's rows from the Lion's assets and from offline measurements of its clips. A shipped row of each
table is only the struct the game copies (`CopyScriptStruct`) before the patches: the recipe sets every field that row
holds, to the Lion's value or to empty. For 894 of the 2087 fields the template holds, the Lion's value is the
template's own (the Behemoth's 180 degrees a second turn, 900 cm/s run and 1.5 s getup time, among others), so the patch
writes that value back. These template rows are Behemoth rows, and a Scarlet effect for the effect row. The one Behemoth
asset a Lion row names is the sound set `CSS_MON_46_BEHEMOTH`: the pak listing holds no sound set for the Lion, and its
blueprint names none.

- Stats, in both CharacterTable rows: 160000 HP, 3300 shield, 14 stamina, 960 physical and range attack, 110 shield
  attack. The Great Desert elites (Behemoth, Stalker, Abaddon) have 170500 HP, 3500 shield, 15 stamina and 840 to 1050
  attack; the Lion has a little less, as a boss with melee attacks only. Its target filter radius (190 cm) and rule-move
  block radius (240 cm) fit the Large blueprint's 150 cm capsule. Rank Elite, difficulty group MonsterElite (the same
  numbers as the Great Desert groups), actor type BossMonster, no reward. Zero stamina applies `M_LinkAttackDelay_10`,
  `Groggy`, `SkillCancel`, `BlockSkill` and `M_StaminaRecoverReady`, as on Stalker and Abaddon; EVE's link attack needs
  the target groggy. Detection is the shipped `M_DetectCommon20m360` (360 degrees, 20 m). The link flag is `Common`:
  EVE's generic link Show plays the Lion's own `Hit_Sword_Normal_LinkAttack1` on it. `Name` stays empty, since
  CharacterStringTable has no Lion text (see the spawn below).
- 21 skills (IDs 5002000 to 5002020), their 21 commands and 80 steps (a skill's ID times 100, plus 2 to 10). Each skill
  plays one Lion Show and follows that Show's steps one for one, in count and in duration: at each new step of the chain
  the game moves the playing Show to its next stage and never matches the Show's step IDs (`FSBSkillPresentationObject`
  queues each step row and reads its ID only for its log). The first 15 are the kit of 0.6.0-beta.1. The others are the
  Lion Shows with a clip that the kit left out: `ClawAttackChain` (three claws), `ClawAttackChain2` (four claws and a
  full turn), `MoveAttackChain` (three claws on the move), `RushAttack` (a leap, then a claw), `DashAttackChain` (four
  pounces over three clips) and `RoarPhaseChange` (the roar Show again, for phase 2).
- A Hit step is the Show step in which the striking claw, paw or jaw peaks. No Lion clip has a hit notify, so the
  striking point and its speed peak come from the decoded clips; their forward kinematics match the socket tracks the
  game bakes for 21 Lion clips within 0.14 cm on the clips' key frames, and up to 28 cm off between keys on fast hand
  frames. On every claw attack the `NS_Lion_ClawTrail_01` particle starts within 0.05 s of the Show's hit step. Six hits
  peak 0.017 to 0.074 s before their step, two of them claws (AttackToBackJump's first hit and MoveAttackChain's third),
  and the generator lists them. A claw strikes through `Mon_Lion_Attack_L_Arm_Collision` or `R_Arm`, a landing through
  `RL_Arm` (both arms). The roar and the dash chain hit through a target filter, since the collision data tracks no
  socket for the dash clips. Five result rows hold the game's own reaction Shows, effects and knockbacks: light (0.5 s
  stun), strong (0.8 s), knockdown (1.5 s), guard and parry. A perfect parry on a skill's last hit goes to the shipped
  step `M_Common_Result_ParryJust_Center`, which plays the Lion's `Result_Hit_JustParry`. EVE can neither parry nor
  guard the roars and the high jump, as with the Behemoth's, and the game's action assist checks them 0.066 s before the
  hit.
- 61 moves (CharacterMoveTable rows). Every Lion clip is in place: the root never moves, and each clip starts and ends
  on the idle pose. The travel the game has to give the Lion comes from each clip's planted feet, and in the air from
  the pelvis keeping its take-off velocity. On the Behemoth's own clips the planted feet give the distances and times of
  its move rows (its ScratchLeft finish: 146 cm over 0.22 to 0.58 s, against the row's 143 cm from 0.2 to 0.6 s); the
  flight estimate does not (its JumpAttackHigh hit step comes out at 1106.6 cm forward and 341.8 cm right against 427 cm
  of rows, its SmashBackflip finish at -1164.9 cm against -1588). A step that travels 30 cm or more gets one move over
  the time its feet move. 24 of these come from planted feet; 29 spend half their time or more in the clip's flight
  windows and are flight estimates, which the generator marks. The other 8 only turn the Lion.
- A move that heads toward where its skill expects EVE (within 60 degrees) goes along the line to her and stops short of
  her: `MovePositionType_InsideTargetOrSelf` with `MoveDirectionAxis_SelfToTarget`, the shape of the shipped lunges of
  Elder phase 2, Scarlet, Raven and Tachy. It goes its clip's length, or less when EVE is nearer, and stops
  `LimitApproachDistance` short of her: where the next strike lands at its peak, rounded down to 10 cm so the strike
  never lands short (150 cm for the low jump's paws, 800 cm for the high jump's, which land 8 m ahead of the root
  inside the clip; the paws reach 893 cm during that hit). That these moves stop short comes from the shipped rows
  (Scarlet's Airspin: 2000 cm with a 200 cm limit), not from the game's code. 43 moves are of this kind;
  the other 10 keep their travel along the Lion's own axes (the side steps, steps and jumps back or sideways, the roars'
  step forward). The side steps keep only their sideways travel (14.2 and 15.9 m), as the forward part is the method's
  error there. BackJumpToAttack has no move: its first step's travel is the net of two opposite flight estimates (-924
  cm, then +740 cm), and the clip spins the body about the root.
- A skill whose travel up to its first hit heads 30 degrees or more off its front looks for EVE there and keeps its
  heading while it moves, as its clip turns the body: RunAttackLeft and RunAttackRight at 80 degrees to the side,
  ClawAttackChaseRight at 40. In every other skill the moves turn the Lion toward EVE, and its first step does so on its
  own when that step has no move: at once for the turn attacks and the back jump, whose clips start with the body turned
  90 or 180 degrees away, else over that step.
- 23 target filters. A skill's range is the reach of its first hit toward where it expects EVE (the striking socket's
  farthest point that way during the hit step, at the mesh's 1.5 scale) plus what its moves close before that hit: a
  move toward EVE its whole length, any other its part toward her, negative when it goes away. The sum is multiplied by
  0.61: the Behemoth's ScratchLeft filter is 300 cm for a claw reach of 440 cm and a move of 53 cm before it. The low
  jump finds EVE within 490 cm, the high jump within 12.6 m, the run attacks within 520 and 550 cm, BackJumpToAttack
  only within 110 cm, as its claw comes down at its own front paws. The turn attacks look behind a side, the back jump
  behind, the roar in a 120-degree arc up to 7 m ahead. Each way the moves take the Lion 3 m or more gets the shortest
  shipped space check (`Valid_Move_*`) that covers it, or the longest of that way when none does (the side steps' 14.2
  and 15.9 m, and the high jump and three chains that go past 18 m forward).
- A skill with a move toward EVE before its first hit only starts when she stands past that move's stop: its filter's
  `NearDistance` is the stop plus 30 cm (the shortest travel that gets a move), rounded up to 10 cm. Seven skills get
  one: the low jump 180 cm, the high jump 830 cm, RushAttack 310 cm, the chasing claws 440 and 230 cm, the run attacks
  130 and 140 cm. Without it a skill could start with EVE inside the stop, and the lunge would hold or step back while
  the strike passed her. SB's own monster skills set no `NearDistance` beside such a limit (none of the 12 whose first
  such move has one, of 200 or 300 cm), and their ranges reach at least that far; the Lion's leaps stop farther out (up
  to 8 m). Where the stop plus 30 cm passes the skill's range (ClawAttackChain, ClawAttackChain2 and DashAttackChain,
  whose first strikes land at 360 to 430 cm against ranges of 340 to 440 cm), the moves before the first hit get no
  limit and go up to EVE, as the first such move does in 74 of SB's 86 monster skills that have one, and the filter
  keeps no `NearDistance`.
- Two anim sets (500200 and 500201) name the Lion's run clips and its `Result_*` reactions, and no shield break, which
  the Lion has no clip for.
- Two stances. `M_LionC_Default` (500200, phase 1) lists 17 commands; `M_LionC_Phase2` (500201) lists all 21. Both walk
  at 200 cm/s, the battle blend space's walk sample, and run at 900, the Behemoth's pace, and turn at 180 degrees a
  second, as the Behemoth does in both its phases (the Raven keeps its 360 in phase 2 too). At the Large scale the run
  clip strides about 1550 cm/s, past the blend space's last sample (600), so any boss pace slides its feet; 900 slides
  less than 600. Phase 2 is the Raven's data-only switch: the CharacterTable rows list it in `StanceAliasArray`, and it
  takes over at HP under 60% (Priority 10, Condition HP, UnderRate, 60). Its start restores the shield and applies
  `M_LionC_PhaseRoar`, an effect whose action uses the skill `M_LionC_RoarPhaseChange` (`EffectAction_UseSkill`, as the
  shipped `M_Scarlet_CounterLinkStart` does). That skill's AISkillFlag is `PhaseChange`, which neither tree picks. The
  first phase has no `MinimumHP_60p`: had the switch failed, that floor would hold the Lion at 60% HP for good.
- The dead row (the Lion's death Show for every kind of kill, then the `M_LionA_Despawn` dissolve) and the appearance
  row (50020, the Large blueprint).
- Two CharacterTable rows, added last: `M_LionC` (50020, the tree `M_Skulling_AI_Test`) and `M_LionC_Lurker` (50021,
  `M_LesserLurker_AI`). Both trees pick skills by their AISkillFlag (MeleeAttack), not by name, which leaves out the
  side steps (MoveAttack) and the phase-2 roar.

The generator writes the data part of `lion/rows.h` and the whole of `cut/lion_rows.lua` from the offline reader's dumps
of the tables, the Lion Shows and the collision data, the pak listing, the SDK and the clip measurements. It refuses a
taken ID or name (in any case, as the game compares names), a missing template, a field the SDK does not place where its
patch writes, and a template value the recipe does not set. It also refuses a value naming a Behemoth row or asset other
than the sound set, and a reference that lands on no Lion or shipped row: steps, skills, commands, stances, moves,
target filters, results, anim sets, effects (also inside JSON effect strings), Shows, clips, blueprint, tree and sound
set. Steps must match their Show's steps, each Hit step must hold its striking peak (0.1 s early or 0.05 s late at
most), and each collision group must exist with every socket tracked for the clip playing. A move toward where its skill
expects EVE must stop short of her, a skill whose move before its first hit stops short of her needs a range that starts
30 cm or more past that stop and ends past its start, a skill that looks for EVE off its front may not turn toward her
while it moves, no range may pass its first hit's reach plus what its moves close, and each way the moves take the Lion
3 m or more needs a space check that way, no shorter than that travel while a longer one ships. Anim sets must name
clips of the Lion's folder, and no stance may hold HP at 60%. Each link flag must pick EVE link steps whose Shows play a
clip the Lion has, and no move may travel over 17 m.

The game reads CharacterTable, SkillTable and CharacterStanceTable by ID, through maps that only its own AddRow fills
(the table's vtable slot `+0x2b0`, `0x14417ba30`). UE4SS's Lua `AddRow` is a raw RowMap insert that those maps miss, and
its `RemoveRow` frees a row they may still point to, so the mod calls neither on a game table. Lua finds the 14 tables
by their fixed paths (`/Game/Local/Data/<table>.<table>`) and sends their addresses in one request:

```
lion rows CharacterTable=0x<address> CharacterAppearanceTable=0x<address> CharacterDeadTable=0x<address>
CharacterStanceTable=0x<address> CharacterAnimSetTable=0x<address> SkillCommandTable=0x<address>
SkillTable=0x<address> SkillActiveStepTable=0x<address> CharacterMoveTable=0x<address>
TargetFilterTable=0x<address> SkillResultTable=0x<address> EffectTable=0x<address> ItemTable=0x<address>
ItemConsumableTable=0x<address>
```

It is one line in `coop-request.txt` (468 bytes at most with the 12 hex digits Lua's `%x` gives the highest plausible
address, under the file's 512). Each of the 14 words comes once, in any order. Each address has 1 to 16 hex digits, is
plausible and is 8-aligned; anything else gets `unknown request`. No console word reaches an address. The native part
trusts none before it checks the table's vtable (`0x146402e10`), its AddRow slot and its row size.

The game thread adds the rows in `coop_tick` only while the cached net mode is 0 and no logic task is in flight (logic
`+0x5c0` is 0, the same check as same-place enemies' force target): no lock guards the tables, and the logic thread
reads them. A shut gate tries again at the next frame and refuses after 300 frames. For each row not added yet, the
native part initializes a block of its own from the row struct, copies the template row into it (CopyScriptStruct),
writes the ID and the patches, resets the game's lazy-init flag (row `+8`) and the arrays the game parses from the row's
JSON strings, then calls AddRow through the table's vtable with the new name. A row goes in once a game run and never
again, so AddRow's own RemoveRow never frees a row that a living Lion reads. The first refusal stops the run before any
later row. The CharacterTable rows come last, so a refused run leaves no Lion to spawn; asking again skips the rows
already in. These calls run under their own SEH latch.

Then the native part reads the rows back through the game's own lookups by ID and writes the `lion=` line of
`coop-status.txt`:

```
lion=off
lion=waiting added=<n>/237 asks=<a> spawns=<s> why=<busy|net|unread> ticks=<t>
lion=rows added=237/237 asks=<a> spawns=<s> char=<k>/2 skills=<k>/23 stance=<k>/2
lion=refused added=<n>/237 asks=<a> spawns=<s> why=<word> table=<table|-> row=<row|->[ detail=<value>]
lion=fault added=<n>/237 asks=<a> spawns=<s> where=<text>
```

`asks` counts the answers; Lua waits for it to grow. `spawns` is the logic thread's spawn manager counter (`0x147032590`
`+0x198`), read every 250 ms once a first request came, `?` until then. It is read through ReadProcessMemory, outside
the SEH latch, so a bad read leaves the last value and never stops the rows. It moves whenever any enemy spawns or goes,
so `core/link.lua` leaves the line out of its change log and `cut/lion.lua` logs what it reads. Lua then reads every row
back through `FindRow` by field name (independent of the SDK's offsets): the ID and each of the 3178 fields the patches
write, from `cut/lion_rows.lua`, which the generator writes with `lion/rows.h` (the Lua test checks the two agree).
2156 of those values differ from the template row's, so reading them back shows the patches landed; the other 1022
restate a value the template holds, which a read-back cannot tell from the copy. It spawns
only when every value matches and the line says `char=2/2 skills=23/23 stance=2/2`. The read-back runs in one frame,
once per `coop lion`; how long that takes in game was not measured.

### The cut stimpacks

The game ships the Burst Stimpack's consumable row (`HP2Burst_Potion`, ID 1004: 400 HP for 600 Burst gauge), the Beta
Stimpack's use condition, effects (20% of maximum HP for 50 Beta energy) and icon, and English text for both, but no
ItemTable row for either. The first 4 rows of the batch make them usable. Each is a copy of a shipped row of its table
with a few fields changed, and the generator restates every other field from that row's dump:

| Row | Table | ID | Copy of | Changed |
| --- | --- | --- | --- | --- |
| `P_Eve_Sword_Normal_Buff_1` | SkillTable | 6000101 | `P_Eve_Sword_Normal_Potion_1` | nothing: the name `HP2Burst_Potion` gives its use skill, which the game never shipped (its Show `P_EVE_SWORD_USE_Buff` ships, its steps do not), so the stimpacks play the health potion's steps |
| `Buff_HP2MP` | ItemConsumableTable | 1032 | `HP2Burst_Potion` | the condition group `CG_Item_ConsumeAllow_HP2MP` and the effects `Item_Buff_HP2MP_ReduceHP` and `Item_Buff_HP2MP_GainMP` |
| `HP2Burst_Potion` | ItemTable | 300013 | `HP_Potion` | text keys, consumable, icon `Item/Burst`, pickup blueprint `BP_Item_HP2Burst_Potion`, no drop pool, 2 charges with no stat override (as `HealGrenade`) |
| `Buff_HP2MP` | ItemTable | 300014 | `HP_Potion` | text keys, consumable, icon `Item/Buff_HP2MP`, no drop pool, 2 charges with no stat override |

The generator checks that each consumable, condition group, effect, skill, icon, blueprint and Show the rows name
exists in the dumps or the pak listing. `nightop/shop.lua` sells both items. Before a buy of one, it calls
`cut/lion.lua`'s `Lion.rows`, which takes the same steps as `coop lion rows` (the tables, the request or the rows
already in, the wait, the read-back) and then hands the end to the shop: the shop checks the buy again and grants it,
or says why the rows are not in. The answer of a buy that waited comes from `coop lion`'s tick.

The Shock Bolt ammo stays out. Its ItemBulletTable and ItemConsumableTable rows ship, and an ItemTable row and the
missing SkillTable row `P_Eve_Gun_ShootShockSlug1_1` would be two more copies, but EVE's gun stances (`P_Eve_Gun`,
`P_Eve_GunBlockSword`) list only `P_Eve_Gun_ShootShockSlugFail1_1` among its commands. Firing it would mean replacing
those stance rows while EVE uses them, and AddRow's RemoveRow frees the row it replaces. All six `ItemStackBullet` stats
are also taken by the shipped ammo, and the drone upgrade that names the Shock Bolt Magazine (`Drone_BulletAdd3_1`) has
no row.

### The cut ChainSpin

EVE's four shipped Tachy Mode skills (ChainStab1, ScrewAttack1, SwordAura1 and ParrySlash1) each have a SkillTable row
(`P_Eve_Tachy_Skill_<name>_1`, IDs 1004501 to 1004504) that names its first step and its AcquisitionSkillTable row
(`TachyMode_<name>`), a SkillCommandTable row of the same name on one of the Beta skill commands
(`SkillCommandState_BetaSkill1` to `4`, a press, `GlobalCommand` set), a place in the `P_Eve_Tachy` stance's
`CommandArray` (the stance runs while EVE has the effect `P_Eve_TachyMode`), and an acquisition row that puts it in its
fixed slot (`ESBSkillSlotType_TachySlot_1` to `4`) and skill tree box. Their steps play Shows under
`CH_P_EVE_01/Skill/`.

The ChainSpin has none of these. The game ships EVE's clip `P_Eve_Tachy_Skill_ChainSpin1` with its root motion data,
the wing clip `P_Eve_TachyWing_Skill_ChainSpin1`, two CharacterMoveTable rows (`P_Eve_Tachy_Skill_ChainSpin1_Move1`,
750 cm forward over 0.8 s, and `_Move2`, 290 cm after 0.2 s; IDs 1004500 and 1004501, next to ChainStab's block) with
their curves, and the icon `SI_TachyMode_ChainSpin1`. No step of EVE's names those moves and no Show of hers plays the
clip. The prologue's Tachy NPC kept them: its skill `N_TachyNPC_SwingChain` plays the Show
`CH_NPC_TachyNPC/Skill/N_TachyNPC_SwingChain`, whose one anim key plays EVE's clip by its absolute path (3.25 s in nine
steps, with trail and rule move keys), and its Hit1 and Cast4 steps take the two moves. That Show has no wing anim key.

The 11 rows after the stimpacks' build EVE's version from it, each a copy of a shipped row with a few fields changed:

| Row | Table | ID | Copy of | Changed |
| --- | --- | --- | --- | --- |
| `P_Eve_Tachy_Skill_ChainSpin1_1_Cast1` to `_Finish1` (9 steps) | SkillActiveStepTable | 100450001 to 100450009 | ChainStab1's `Cast1`, `Cast2`, `Hit1`, `Hit5` and `Finish1` steps | the Tachy NPC's durations (0.5, 0.15, 0.1, 0.1, 0.15, 0.1, 0.8, 0.1 and 1.25 s), the chain of step names, the Show on `Cast1`, `Move1` on `Hit1` and `Move2` on `Cast4`; on the four hits ChainStab's results `Hit1`, `Hit2`, `Hit3` and `Hit5` (a 1.5 s stun), a quarter of the damage each and the 1000 cm hit area `P_Eve_Sword_1000_360_500_HitArea`, as the NPC's |
| `P_Eve_Tachy_Skill_ChainSpin1_1` | SkillTable | 1004500 | `P_Eve_Tachy_Skill_ChainStab1_1` | its first step; no Tachy Fusion branch, no acquisition, no achievement tag (`TachySkill`), so a use moves no trophy counter |
| `P_Eve_Tachy_Skill_ChainSpin1_Use` | EffectTable | 1004500 | `M_Scarlet_CounterLinkStart` | `EffectAction_UseSkill` of the skill above, with the condition `P_Eve_TachyMode` |

The steps keep ChainStab's hit collision (`Collision_WeaponAndRightArm`, which EVE's collision data has) and its step
effects. The generator checks that the step chain from `Cast1` lasts as long as the Show's own steps, one for one, that
every clip the Show plays is in the pak listing, that the steps' moves are rows of the dump and that the effect's
condition names a shipped effect. There is no SkillCommandTable or AcquisitionSkillTable row: the four Beta skill
commands are taken in Tachy Mode, and a fifth command would have to go into the `P_Eve_Tachy` stance row, which the
native part could only replace while EVE uses it (AddRow frees the row it replaces).

`coop chainspin` (`cut/chainspin.lua`) starts it. It gets the rows in through `Lion.rows`, as the shop does, then calls
`ServerRequest_Cheat(<EVE's GUID>, 0, "SBApplyEffectMe", "1004500")` on the player controller. The request's
implementation queues an `FSBCheat` logic request (`0x141afe5e0`); its `Simulate` (`0x141b11800`) finds the actor by
GUID, reads the first argument as a number and calls the effect function `0x141ad08b0` (the one the shared fight's job
calls) with the actor as target and caster. The effect's action 69 turns its `ActionValue1` into an FName, finds the
SkillTable row by that name (`0x141a9a620`) and calls `FSBActorLogicObject::UseSkill` (`0x141ba23c0`) with the row's ID.
The effect's condition keeps all of it to Tachy Mode. Two other ways were ruled out in the disassembly:
`ServerRequest_UseSkill` builds an `FSBUseSkill` request whose `Simulate` looks for a command node in the actor's
stance and global command lists and does nothing without one ("skillCommandNode is null"), and the cheat manager's
`SBPlayerUseSkill` only reads its argument in this build. EVE's GUID comes from the engine line's `me=` (the key of the
world's player map, which the revive uses too); nothing is asked while `warp=` says busy. None of this has run in game.

### The spawn

The spawn is one call, `nightop/run.lua`'s, with key 0:
`ServerRequest_CreateActor(<charId>, <location>, (0, <yaw>, 0), false, true, 0, 0, 0, None, false)`. Cheat on lets it
take any CharacterTable ID at any place. The charId is fixed in code: 50020, or 50021 after `coop lion brain lurker`;
`coop lion control` spawns 50110 (M_Antlion). The place is 10 m ahead of EVE and 1 m up, facing her. Key 0 is
EventSpawnId 0, as the game's own summons spawn. The body is the new character of the Large blueprint's class nearest
the spot, looked for at 0.3, 1, 2, 3.5 and 5 s (`FindAllOf` walks every object). One that still has no controller 1.5 s
after the call gets its default one (`SpawnDefaultController`, as `nightop/run.lua` does). Its death is read from
`InteractionState` and `Controller`, as `nightop/run.lua` reads it. The game can send a Lion body far away and reuse
it for the next spawn (a Lion 466 m away came back on 2026-10-23), so a body that stood more than 100 m from the spot
at the call and stands within 30 m of it after counts as the new one; its old follow line ends as recycled.

While a Lion lives, the follow line also carries what the first test lacked: the body's place, the speed its blend
space reads (`GetSBSpeedForAnimGraph`), whether a skill runs (`IsRunningSkill`) and the two custom anim alphas the
animation blueprint blends a Show's clip by (`GetCurrentCustomAnimAlpha(0)` and `(1)`). Two more checks run once a
second. The loaded line looks for the 20 Lion Shows of the kit and the clip each one's first anim key plays, with
`StaticFindObject`, two paths a second (a call costs about 4 ms), each until first seen: the game loads a Show when a
step plays it, and the Show's anim key loads its clip. The boss name looks for the live `TextBlock_BossName` (under
`/Engine/Transient`; `FindAllOf` again at most every 10 s while none is held) and sets it to `Lion` where it reads
`<M_LionC>`. The game writes that block once per boss bind (`FText::FromStringTable` on the row's `Name`), so the check
puts the name back after each bind.

`coop lion intro` first plays `Mon_LionC_Scene01_Appearance` (13 s, the clip of the cut boss intro
`DesertedCity_LionBossIntro`) on a display copy: `race/doro.lua`'s plain actor with the `CH_M_NA_02_Large` mesh at the
blueprint's scale (1.5), on EVE's feet at the spot, facing her. At the clip's end the Lion spawns where the copy's bone
0 stands, at the spot's height. When that is more than 20 m from the spot, it spawns at the spot. The copy goes as soon
as the body shows, before the body's controller is checked, so the two never stand together. A map change during the
entrance spawns nothing. The clip does not play on the Lion itself: `CH_M_NA_02_AnimBP` has no slot node, so a montage
would not show; a single-node clip would replace the anim instance the game plays the Lion's skills on while its AI
runs. The copy is in no file, so a Lua reload during its 13 s leaves it until the map changes.

### What stays out

- Quests: a key-0 actor has no EventSpawn row, so no EventOnSpawning, EventOnBattle or EventOnDead runs. The one Lion
  quest task in the game's data, `EQ_DownTown_Quest_05_T01`, goes through spawn point 71, not an alias. Quest or
  condition tasks that count kills by tribe or actor type were not checked.
- Saves: an actor with no EventSpawn row is not in zone storage, so a save should not bring a Lion back (not checked in
  game). The rows are never written anywhere. The command spawns only on a co-op save.
- Achievements: a kill by EVE counts for the two Kill rows that take any enemy (`Kill_Character` and
  `Trophy_KillCharacter`), as any Naytiba kill does. It unlocks no album entry. On a boss bind and a boss kill, the game
  hands the row name to an achievement container through obfuscated code; whether that keeps anything was not
  established.
- Co-op: shared enemies pair by spawn key, and a key-0 actor has none, so the Lion stays in the game of the player who
  typed the command. Sharing one would need a key range of its own, a host spawn through `NewActor` in the shared
  fight's job, a guest rule in same spawns, a `kBosses` row and a protocol bump.

### Open questions

Only the game can settle these:

- whether the game's lookups by ID see the rows and the read-back matches on this build;
- whether the stance's command list builds the Lion's command set and `M_Skulling_AI_Test` runs on it;
- why the Lion stays in its idle pose: the game never plays its Shows on that body, the Shows play and their clips do
  not load, or the clips load and the animation blueprint does not blend them in (the follow and loaded lines tell
  these apart, and `coop lion control` tells the spawn call from the rows);
- why `InteractionState` reads 1 (executable) from the first second of the fight;
- whether the Lion walks to EVE or stands while she moves around it (the follow line now logs its place);
- where the lock-on marker sits, whether its feet meet the ground and whether its hit sounds play;
- what a key-0 death does to the spawn manager's counter;
- each AddRow runs the game's table-changed handling over the whole table, so 220 of them in one frame may cause a short
  hitch, not measured;
- whether the game's lookups of the 4 tables new to the rows (moves, target filters, results, effects) run the same
  lazy init as the other 8;
- whether `EffectAction_UseSkill` fires from a stance's start effect, so that the phase-2 roar plays (every shipped use
  comes from one of EVE's steps), and what it does when the Lion is in the middle of another skill;
- whether the moves mostly in the air (29 of the 61, a ballistic estimate) carry the Lion as far as its clips show,
  and whether a move with `MoveTransformType_None` turns the Lion at once for the turn attacks, whose clips start with
  the body turned;
- whether an `InsideTargetOrSelf` move stops `LimitApproachDistance` short of EVE as the shipped lunges suggest, what
  it does when she already stands closer than that, and whether the high jump, whose paws land 8 m ahead of the root
  inside the clip, still passes over an EVE nearer than that;
- how far each skill's range lets EVE stand before the Lion uses it, and whether 160000 HP makes a fight of the right
  length.

## Developer flight and slow motion

`coop fly` and `coop slowmo` switch on two developer gates that the game ships off (`game/debug_keys.h`, run by
`glue/tick/debug_game.inc`; not tested in game yet). EVE's character tick reads the flight key (R2 or Z) only through
one function (`0x1423c9ea0`) and the time-control key (R1) only through another (`0x1423c9f90`), and each passes its key
on only while its gate reads true. A gate is one bool in a settings singleton of the game's, not a UObject: the pointer
at `0x147032540` (the globals block's `+0x18`) leads to a `TMap<int32, bool>` at `+0xa8`, keyed by the
`Strihash_DEPRECATED` of the gate's name (`UseFlyingActionKey` `0x1147F83C`, `UseTimeControlKey` `0x43812976`), which
its constructor fills with false. The cheat command meant for them, `USBCheatManager::SBSetCustomBool`, does nothing in
the shipping build, and the character's own `SetCustomBool` writes another map, so no Lua call reaches them.

Every 250 ms while a gate is wanted, the game thread looks its key up as the game's lookup (`0x14261db60`) does and
writes 1 into the value byte of the element it finds. It first checks that the gate function's own copy of the key (a
static that function fills at its first call, at `0x1471082ec` and `0x1471082f4`) holds the same key, that the map's
counts and buckets are in range and that the byte reads 0 or 1. It never inserts an element. The reads go through
`ReadProcessMemory`, and the one write runs under the gates' own SEH latch. The value read before the first write goes
back once the gate is no longer wanted: `off`, `coop off`, the next Lua load (the worker clears the asks when Lua's
session token changes) or a save that is not a co-op one. Slow motion is wanted only while no friend is linked, since
time dilation is local. If the game builds the map again (its values back to false), the next pass sets the gate again
and the log says `gates set again`. A missing key, a static that holds another key or a map out of range refuses the
gate on screen, with no write. The worker numbers each ask and hands the number over with the gates it wants; the game
thread hands back the number its last pass read. A gate's state is logged, and a refusal said, only from the first pass
that read its ask, so a state left from before the ask never reaches the log or the screen.

With the flight gate on, the character tick starts a flight while the key is held in the air (the falling movement
mode) and the time pool allows it (`RemainFlyingActionTime` at least `FlyingActionEnableRemainTime`, 3 s, and no
cooldown), and ends it when the key is released. With the slow-motion gate on, holding R1 sets the time dilation to
`TimeControlKeyScale` (0.2), and every tick without it sets 1 again, so slow motion ends by itself.

The start and the level flight (`Hold` in `game/debug_keys.h`) set the flight key's flag after the game's key pass.
The player controller's input pass (`0x1423c47a0`, its `ProcessPlayerInput(dt, paused)`) recomputes `USBPlayerInput`'s
`bPushedFlyingActionKey` (`+0x193`) and `bPushedJumpKey` (`+0x197`) from the keys held each frame, through
`0x1423c86f0`, and EVE's tick, which runs after the controller's, starts a flight while the flight flag reads true in
the air and ends it when the flag reads false. A write from Lua came before the pass, which cleared it, and one from a
hook on EVE's blueprint `ReceiveTick` came after the character tick's check: both times the flight ended 0.02 s after
the keys were let go. The pass is called only through two vtable slots, `0x145cc74a8` and `0x145cd37a8` (its other
references are unwind data). At the first `coop fly on` of a run, the worker swaps each slot by a compare-and-swap from
the game's function to a hook of ours, only after checking that both hold exactly that function. The hook calls the
game's pass, then, on the game thread, while both slots hold it, the fly gate is ours and the game is not paused, reads
the controller's pawn (`+0x2f8`) and input handler (`+0x668`). The jump flag is set on every frame a key of
`DefinedJumpKeyLists` (`+0xF8`) is down (`0x1423c887e`), so the hook takes a press as the flag going from 0 to 1, and a
key already down when the hook first reads it counts only once let go and pressed again.

The hook counts the space bar's presses since EVE left the ground. She is on the ground when her movement component
(`ACharacter`'s `+0x330`) has a `MovementMode` (`+0x19C`) other than falling (3): the pinned build's `IsFalling`
(`0x1440a5b80`, in the movement component's vtable) compares that byte with 3. There the count is 0, or 1 while the
press she jumps with is still down or less than 0.3 s old (game time, from the pass's own delta), since her
jump may leave the ground a frame or more after the press and a short tap can end before that. Each press in the air
adds one. From the third press, while the space bar is down and her `bFlyingAction` (`+0x1101`) reads 0, the
hook writes 1 into the flight flag, as a held R2 would, and the character tick starts the flight when its own checks
allow it. With `bFlyingAction` at 1 and the flight flag at 0, it writes 1, so she flies level. The press that started
the flight is still down when the flight begins, so it is no rise. The next press stops the writes until the flight
ends, so the space bar drops her, and the count starts over at 0. While `coop fly` is on, `cut/flight.lua` writes R2
over Z (and over any third slot) in `DefinedFlyActionKeyLists` (`+0xC0`), so Z and S, which walk forward and back on an
AZERTY keyboard, no longer start a flight; it puts Z back at `off`, `coop off` and the next Lua load. The reads go
through `ReadProcessMemory`; the write runs under the hook's own SEH latch, and a fault puts both slots back for the
run. `coop off` puts them back too. The pass recomputes both flags each frame, so nothing else needs putting back.

## Cut glide

`coop glide` (`cut/glide.lua`, not tested in game yet) plays the part of a cut piece of EVE's movement code. In the
pinned build, `ASBCharacter`'s `bGlide` (`+0x1100`) has four readers and no writer. The movement component's gravity
(`0x14214d380`, its `GetGravityZ` slot) checks it before the flight and the wall run and scales gravity by
`GlideGravityScale` (`+0xC80`, 0.1). Its air control (`0x142154f80`) scales by `GlideAirControlScale` (`+0xC8C`, 1.0,
the same as without a glide). The reflected `IsGlide` (`0x142686080`) returns it, and the movement debug print shows it
as `Glide %s`. No instruction writes it, and nothing reads `GlideHoldKeyDurationOnJump` (`+0x1360`, 0.2) or
`RemainGlideKeyHoldDuration` (`+0x1364`): the hold-Jump code that set and cleared the flag was cut. Unlike the flight,
no setting gates it, so no write to the settings map could turn it on.

`bGlide` is a reflected property, so Lua sets it. Each frame while `coop glide` is on, the module reads the player's
EVE and her movement's `IsFalling`. In the air it also reads her velocity, `bFlyingAction` and the game's default Jump
keys (`SpaceBar`, `Gamepad_FaceButton_Bottom`) through the player controller's `IsInputKeyDown`. A glide starts once
Jump has been held for 0.2 s of her world time (`GetGameTimeSinceCreation`, which stops in the pause menu) while she
falls with a velocity Z at or below 0 and is not in the flight, and it ends as soon as one of these no longer holds.
The velocity check keeps a held jump from rising ten times higher, as the low gravity would also act on the way up. A
hitch counts as 0.1 s at most, and another EVE (a map change) starts the hold over.

The module writes `bGlide` only when a glide starts or ends, on the player's own EVE. It puts false back at
`coop glide off`, at `coop off`, when her EVE changes and when the save is not a co-op one (`coop_slot`, read once a
second). A failing frame puts it back and turns `coop glide` off with a line on screen. Since no code of the game sets
`bGlide`, a true value at the next Lua load can only come from an earlier load, so that load's first tick sets false
on the player's EVE when it reads true. The property is transient: nothing of it reaches a save.

## Achievements

The mod calls no achievement function. Each game raises its own Kill achievement, kill rewards, drops, quest kill tasks
and a boss's story events from a death in its own world, with the death's cause as the killer. Shared enemies keep one
rule there: a fight done together counts for both players, and nothing done without a player reaches that player's
save. The rule applies where the mod makes a death, the other game's kill (the host's `dead`, or the guest's lethal
claim the host accepts):

- That kill kills our copy, with our EVE as the cause, only when our EVE took part in its fight: a drop on our copy
  that no write of ours made (her own hit), our EVE as the game's last player on the copy, or, with
  `kill_credit=together` (the default), our EVE within 30 m of the copy (FSBActor `+0x4cc`) at the kill. The last
  player is the GUID at logic actor `+0x638`, which the game stores (`FUN_141ba8190`) when an enemy targets a player or
  a player's hit lands, and which its death handler (`FUN_141bae5d0`) takes as the killer of a death with no player
  cause. No EVE of ours found counts as no part. Damage from before the enemy was shared or paired does not count as
  our hit: the other player's claims before a pause hurt it too.
- Our mirrored crowd controls go through the game's effect call (`FUN_141ad08b0`) with our EVE as the caster. Whether
  that call can reach `FUN_141ba8190` is not ruled out, so the engine reads `+0x638` before and after each such call:
  a copy on which it turned into our EVE is noted for the session (`last player ... set by a mirrored crowd control`),
  and its `+0x638` no longer counts as our part.
- Without part, our copy does not die, since a death with no cause still drops loot, records the death in the zone and
  runs the enemy's death events. It goes back to its full HP, with no cause and no damage number, so one hit later
  does not finish what the other player's hits did. The guest ends the pair (`dead-unshared`), so her copy lives on as
  her own enemy, its floor, scaling, freeze and finish guard taken off, until same spawns' next drop despawns it (the
  host lacks it), which is no kill. A boss copy is back above 1 HP before the guard is taken off, so the guard keeps
  the boss's Immortal. The host keeps its copy alive, leaves it out of its later
  censuses and of same spawns (`kill-unshared`), and sends `dead`, so her copy dies on her side's own test.
- A boss's `bstart` runs SetBattleMode on her copy only while her EVE is within 30 m of it or its last player, so its
  battle-start events never run in her world for a fight she is not in.
- The 30 m clause counts only while our EVE is alive (life state 1 or 6), so a dead EVE gets no kill made next to her
  body. While a player is down, the hand-overs move an enemy only within 30 m of the EVE that takes it
  ([A player down](#a-player-down)).
- `coop fight test kill` (the solo probe) kills only an enemy our EVE took part in, by the same test with the 30 m.
- The [spawn filter](#the-spawn-filter) (off by default) refuses the guest's spawn of an enemy the host's game lacks
  and never kills, so no kill, reward, drop, quest kill or achievement comes of it, and no death is recorded in her
  zone.
- The mod's kills pass no skill to ApplyStat, so they never count toward the skill-kill achievements. The mirrored
  crowd controls and the HP corrections never kill, and the game's AchievementTable has no row for a hit.
- [Shared quests](#shared-quests) keep the same rule: the guest's game takes a host step only when her quest stood
  where the host's did and she stood in the host's zone when its line came. A kill task waits for her own copy to
  complete it, by her own kill or by a shared enemy that died in her world under the rule above. `coop quests force`
  never applies a step of a quest she is behind on.
- Night Operation keeps the same rule. With shared enemies off, each world fights its own copy of each wave monster,
  and each kill is that player's own. With them on, a wave monster pairs like a field enemy, and its death reaches a
  player's save only by the took-part test above. The shop's points go only to a player whose own game ran the run from
  its countdown to a success or a time up: each game credits its own player, a guest whose game missed the countdown
  gets none, and no line between the games carries points.
- The challenges run only without a Steam session: a start refuses one, and a session that starts ends the run. Their
  kills are the player's own, and they give no shop points. A best run goes into `coop-records.txt` only on the PC
  whose own solo run ended in success, never from a co-op run and never over the link.
- The travel to the host takes only camps that a read of the guest's save confirms as activated, because activating a
  camp counts toward achievements ([Following the host](#following-the-host)). That read does not exist yet, so the
  travel makes no call at all. A revive changes only the downed player's own EVE: her life, her HP and the recovery
  items that a camp respawn refills too. The cutscene wait is a pause, and the solid partner changes no game state.
- A [Doro race](#doro-races) gives nothing to either player: its Doros cannot die, and it calls no achievement, reward
  or save function.
- A [Lion](#the-cut-lion) lives only in the world of the player who typed the command and is never shared: its kill is
  that player's, like any Naytiba's.

## Safety design

StellarCoop reads and writes game memory, so it fails closed: a failed check or a fault stops the affected feature or
drops the input.

- Before it reads any engine memory, the native part checks the game's exe against the pinned build (Steam build
  24463856): its PE time stamp, its image size and 19 code bytes. On any other build the pose path stays off
  (`engine=off reason=...`) and nothing is read. The save slot read, the vitals read for the partner card and the
  Night Operation poller also run only on the pinned build.
- Every engine access in `coop_tick` runs under a Windows structured exception (SEH) guard. The first fault latches the
  feature off for the run and is logged with its code, the DLL offset, the address and the part. Effects have a latch
  of their own. A fault inside Steam in the worker (for example a call racing the game's Steam shutdown at exit) stops
  the link and the pose path for the rest of the run (`stopped=fault <code>`) instead of crashing the game. The log's
  last line gives the reason the worker stopped.
- The save slot read, the vitals read and the Night Operation poller read through `ReadProcessMemory`, which returns an
  error instead of faulting, and only after a plausibility check of every pointer and count.
- `coop_tick` never blocks the game thread. It runs once per engine frame (it checks the engine's frame counter) and
  shares only atomics and a lock it never waits on: when the worker holds the lock, the hand-over waits for the next
  frame. Nothing is allocated under the lock: the worker sizes the pose buffers beforehand and the game thread only
  swaps them. Every 60 s the log gives the tick's cost and, while poses flow, the stream's counts.
- Everything from your friend's game is checked before use: the table parser and the pose decoder (both fuzzed by the
  tests), the mesh path rule, the channel 1 size and rate limits, at most 8 effect starts a second, and race lines
  (printable ASCII, 512 bytes and 40 lines a second at most, then the bounds in [Race lines](#race-lines)).
- The [Doro look](#the-doro-look) and a race's [driving](#driving) are the only writes to the player actor. The look
  writes `bHiddenInGame` on EVE's mesh parts and `VisibilityBasedAnimTickOption` on her main mesh. It writes
  `coop-look.txt` before it changes either, and undoes both at the race's end, on `coop race look off` and `coop off`,
  after a map change and at its first error. It also sets `bHiddenInGame` on the main mesh of the drone that follows
  EVE, records the drone in the same file first, and clears it again on the same exits. The driving sets four values of
  her movement component to 0 and gives it a velocity and her a yaw each frame. It writes `coop-drive.txt` before it
  changes the values, and puts them back on the same exits. The next Lua load undoes either from its file when this one
  could not.
- The co-op save copies (`StellarBladeCoop00.sav` to `04.sav`) are made only on a `saves convert`, `saves coop` or
  `saves refresh N` request (the question on the title screen, `auto_coop_save=always` or `coop saves`), and only at the
  title: Lua reports the title screen (`world=title` in `coop-state.txt`), no save is loaded, and Continue or Load Game
  was not chosen (the game's load mode is 0). A pass checks this again before each file and before the switch. The
  native part reads your saves and writes each copy as a `.coop-tmp` file, renames it over the copy and reads it back.
  One name check guards every write: only the copies, their temporary files, `StellarCoopSaves.txt`, the shared quests'
  records `StellarCoopQuests00.txt` to `04.txt` and the backup in `StellarCoopBackups` pass it. The backup is taken
  before any copy whenever `StellarCoopSaves.txt` does not exist yet, and a refresh backs up the copy it replaces first.
  The switch to the copies is one 8-byte compare-and-swap in the game's memory, on the pinned build only, read back
  every 250 ms; an entry that moves or changes stops it for the run.
- The [spawn filter](#the-spawn-filter), off by default, is the one write into the game's image rather than into
  memory the game allocated: one 8-byte pointer in `.rdata`, swapped by compare-and-swap from the game's own value
  only, with the page writable for that store alone, and swapped back from the mod's value only at `coop off` or after
  a fault. A slot that holds another value is never written.
- Except for those copies, the mod never reads or writes a save, unlocks or equipment. It adds to the inventory only
  for a Night Operation shop buy (`coop nightop buy`, co-op saves only), through the game's own request
  (`ServerRequest_ItemBucketItemAdd`) with one of four items and 1 to 10 of it. Apart from enemy stats with the
  experimental shared enemies (`coop fight`, on by default, co-op saves only), their positions and animations with the
  experimental same place (on by default), the quest steps of the experimental shared quests (off by default, co-op
  saves only, made by the guest's game through its own quest functions) and a Night Operation run's state on the night
  line, nothing is copied between the two players' games. Beside
  the saves it reads only the co-op marker `StellarCoopSlot.txt` and the copies' manifest `StellarCoopSaves.txt`; Lua
  only checks whether a copy exists, opening none of your own saves. See [saves.md](saves.md).
- The follow and the revive call the game's own functions on the local player only. A travel runs on the guest's own
  request, on a co-op save, for a camp of her own table that her game already knows by name, under its own SEH latch:
  a fault turns it off until the game restarts. The revive calls the game's respawn on the downed player's own EVE,
  once per death, at the death screen only. No address, pointer or name index goes over the network for either.
- `coop lion` adds [the Lion's 78 rows](#the-rows) to the game's tables through the game's own AddRow, on the game
  thread with no logic task in flight, after a check of each table's vtable, AddRow slot and row size, under their own
  SEH latch. No shipped row changes, no row is added twice and nothing is written to disk.
- `coop off` stops engine access, the link and every feature until the game restarts, even across a Lua reload,
  because the native part keeps the flag.
- The DLL pins itself in memory, so a Lua reload that frees the script's libraries never unloads code the worker is
  running. It also pins Steam's DLLs, so a call in flight at game exit returns into mapped code.

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

The commands are in [usage.md](usage.md#solo-testing-loopback-record-replay).
