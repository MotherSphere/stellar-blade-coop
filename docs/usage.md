# Keys and console commands

To install the mod, see [INSTALL.md](../INSTALL.md). For what happens behind each feature, see
[how-it-works.md](how-it-works.md).

Close the game before you change any file in the mod folder.

## Keys

The keys work with or without the console. They need the native part (`StellarCoop.dll`).

| Key (default) | Action | Console equivalent |
| --- | --- | --- |
| F5 | Open or close the [co-op menu](interface.md#co-op-menu); its first row hosts a session. Within 3 m of a camp phone booth, open the [co-op line](interface.md#co-op-line) instead | (none) |
| View held 1 s, on a [controller](interface.md#controller) | Open or close the co-op menu, or the co-op line at a booth | (none) |
| F6 | Show the status: one line on screen (see [Notices](interface.md#notices)) and in `UE4SS.log` | (a short form of `coop status`) |
| F7 | As the guest, travel to the camp nearest the host, or cancel the travel that `follow_host=always` is about to start; off in this version ([Following the host](playing-with-a-friend.md#following-the-host)) | `coop travel host` |
| F8 | Leave the session | `coop leave` |
| F9 | While you record a [Doro race](doro-races.md) track, set a checkpoint where EVE stands; nothing otherwise | `coop race cp` |
| Enter | During a session, open the [chat](interface.md#session-chat) box, then send a line; Esc closes the box | (none) |
| none | Host a session at once, or open the Steam invite dialog again while you host (`host_key`) | `coop host` |

You can change F5, F6, F7, F8 and F9 in the menu's Options page or in [coop-settings.txt](settings.md#coop-settingstxt), and
`host_key` in the file only. A key passes its action to the game thread, where the same checks as for the console
command apply (`coop off` included). The log says `key F5: menu`. The other keys then log the usual `OK:` or `STOP:`
line; the menu key logs one only when the menu cannot open.

Before the menu existed, F5 hosted. A settings file written by an older version has no `menu_key` line: the menu then
opens on that file's `host_key` (F5, or the key you set there, such as Shift+F5), and no key hosts at once. To keep a
key that hosts at once, set both `menu_key` and `host_key`.

## Console commands

The console comes with ConsoleEnablerMod (see [INSTALL.md](../INSTALL.md#requirements)) and opens with F10 or `~`.
Every command starts with `coop`. Each answer goes to `UE4SS.log` as a `[StellarCoop] OK: ...` or
`[StellarCoop] STOP: ...` line. An unknown command prints the usage line.

| Command | What it does |
| --- | --- |
| `coop host` | Host a session (2 players, friends-only; invited only with `who_can_join=private`) and open the Steam invite dialog (the menu's Host a session row); with `who_can_join=code`, host with a [join code](playing-with-a-friend.md#join-codes) and no dialog |
| `coop invite` | Open the Steam invite dialog again while you are in a lobby |
| `coop join` | Join the first Steam friend found in a Stellar Blade lobby |
| `coop join <lobby id>` | Join that lobby (digits only) |
| `coop join <code>` | Join the lobby of that [join code](playing-with-a-friend.md#join-codes), in capitals or not, with or without the dash |
| `coop copy` | Put your join code on the clipboard while you host with one (the menu's Copy my code row) |
| `coop allow <SteamID>` / `coop deny <SteamID>` | Let in or refuse the player who is not your Steam friend and waits for your answer |
| `coop remove <SteamID>` | Remove a player from the session you host; they cannot come back to that lobby |
| `coop leave` | Leave the session (F8) |
| `coop travel host` | As the guest, travel to the camp nearest the host (F7), or cancel the travel that `follow_host=always` is about to start; off in this version ([Following the host](playing-with-a-friend.md#following-the-host)) |
| `coop travel probe <camp>` | Solo test of the follow's travel: the game's own fast travel to one of its 120 camps that your save has activated (the `activated=` line of `coop status`), with no session and no host's answer; any other camp is refused, see [Following the host](playing-with-a-friend.md#following-the-host) (test command, co-op save only) |
| `coop status` | Print the full state: link, friend, notices, pose path, save slot, ghost |
| `coop report` | Write `coop-report.txt`, to send with a bug report |
| `coop mark [text]` | Write a numbered line in your logs and your friend's, to line up the steps of a [test played together](#coop-mark) |
| `coop where` | Print one line of positions to compare between two PCs |
| `coop near [metres]` | Print the zone objects the game spawned within that range of EVE (8 m by default, 100 at most), nearest first: row, class, position, state, whether hidden, whether it collides. A test tool for the Matrix XIII map |
| `coop puppet` | Turn the ghost on or off by hand |
| `coop basesuit` | Draw the ghost's body and hair on the base suit, or back on her own meshes |
| `coop look` | Show which looks are on |
| `coop look <cloth\|dyes\|effects> <on\|off>` | Turn one look on or off until the mod reloads |
| `coop cns` | Show whether the ghost's CNS part is on and which mod assets the crash sentinel set aside |
| `coop cns reset` | Clear the set-aside list, turn the CNS part on again and build the ghost again |
| `coop wear [<name>\|off [hair\|suit]]` | Put a [cut hair or suit](cut-eve.md#cut-hairs-and-suits-coop-wear) on your EVE (display only, untested in game), or give the game's back |
| `coop lines [<name>\|stop]` | Show the subtitles of a [scene cut before it was voiced](cut-scenes-and-menus.md#cut-scene-lines-coop-lines) in the chat's feed, or play unused voice takes, or end it (untested in game) |
| `coop emote [list\|<name>\|off]` | Play one of [EVE's clips](cut-eve.md#emotes-coop-emote) (a photo-mode pose held until she moves, a wave, a clip of the Cut category; untested in game), list them or end it |
| `coop loopback <delay ms> <jitter ms> <loss %>` | Run your own ghost through a simulated network on one PC |
| `coop loopback off` | Stop the loopback |
| `coop record` / `coop record off` | Record what you send (table and poses) to `coop-record.bin` |
| `coop replay` / `coop replay off` | Play `coop-record.bin` back as a ghost, in a loop |
| `coop nightop [start [easy\|normal\|hard\|nightmare] [noaggro\|nomove]\|stop]` | [Night Operation's run](night-operation.md#the-solo-run-coop-nightop) at one of four [levels](night-operation.md#levels), solo or, started by the host at his level, [for both players](night-operation.md#the-co-op-run) (one solo run in game, on 2026-10-28, tracked none of its monsters and spawned some inside walls; the fixes for the tracking and for the spawn points are untested in game; co-op save only; `stop` on any save) |
| `coop nightop revive` | In a co-op run with `revive=on`, while your EVE is down: revive her yourself, a few times a run ([Down and revive](night-operation.md#down-and-revive)) (untested in game, co-op save only) |
| `coop nightop shop` | Night Operation's [reward shop](night-operation-shop.md#the-shop-screen-coop-nightop-shop) in the game's own shop screen, your points as Beta Seeds, with its seven items (two cut stimpacks and the cut [Shock Bolt](night-operation-shop.md#cut-ammo-shock-bolt) ammo among them; the Shock Bolt only once EVE's gun can fire it) (the screen opened in game; buying from it is untested; co-op save only) |
| `coop nightop buy [<n> [count]]` | The same shop from the console: your points and its seven items, or a buy of 1 to 10 of one of them (untested in game, co-op save only) |
| `coop challenge [<name>\|stop]` | [Challenges](challenges.md): the list with each best run, a start by name or number (1 to 5), or the end of the run that is on (untested in game, co-op save only; solo but the [Shooting Range](challenges.md#shooting-range), which the host can start for both players; `stop` on any save) |
| `coop no [heal\|rule\|spawnpt\|actor]` | Night Operation probe (research preview, co-op save only) |
| `coop recruiter [off]` | Night Operation recruiter (research preview, co-op save only) |
| `coop scene [emil\|orcal\|stop]` | Play a [cut scene](cut-scenes-and-menus.md#cut-scenes-coop-scene) through the game's cutscene player (untested in game, co-op save only), list the scenes or stop the one that plays |
| `coop leviathan`, `coop gardener`, `coop tendril`, `coop mann`, `coop nier`, `coop orcal`, `coop enya`, each with `[list]\|show\|move\|skin\|cam\|play\|off` | Read a [cut model](cut-enemies.md#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril)'s assets, or show it in front of EVE with a [free camera](cut-enemies.md#free-camera) to film it, one model at a time and no enemy spawned (test commands; `show` and the camera turned on on a co-op save only) |
| `coop lion [intro]\|rows\|control`, `coop lion brain skulling\|lurker`, `coop lion unfreeze [init]` | The [cut Lion](cut-enemies.md#cut-boss-coop-lion) as an enemy to fight (test command; fought in game on 2026-10-24): spawn one, with its entrance first; add its rows only; spawn an Antlion through the same call; pick the tree of the next Lions; put back the engine switches that can freeze its mesh (spawns on a co-op save only) |
| `coop gardener fight [intro\|half\|skulling\|rows]` | The [cut Gardener](cut-enemies.md#cut-enemy-coop-gardener-fight) as an enemy to fight (test command, untested in game): spawn one, with its entrance first, at half size, or with the Lion's tree; add its rows only (spawns on a co-op save only) |
| `coop tendril fight [rows]` | The [cut Tendril](cut-enemies.md#cut-enemy-coop-tendril-fight) as an enemy to fight (test command, untested in game): spawn one, with the Shows of its attacks built in memory first; add its rows and build its Shows only (spawns on a co-op save only) |
| `coop chainspin` | EVE's [cut Tachy Mode ChainSpin](cut-eve.md#cut-tachy-skill-coop-chainspin), started once while she is in Tachy Mode (test command, untested in game, co-op save only) |
| `coop mxiii` | A camp travel into the [cut Matrix XIII dungeon](matrix-xiii.md) and a camp there (experimental test command; the travel arrived in game with test pak v2 after a reload, the rows at the title are untested; needs the zMXIII_P test pak, which the mod does not ship; solo, co-op save only) |
| `coop mxiii 30` | The same with a travel to a second camp, in the dungeon's third zone (experimental test command, untested in game; needs the v3 test pak; solo, co-op save only) |
| `coop mxiii leave` | The way out of Matrix XIII: a travel back to the camp where EVE respawned before `coop mxiii`, or to another camp your save has activated (test command, untested in game; solo, co-op save only) |
| `coop lily signal` | [Lily's signal](lily-signal.md) by hand: the mod's quest "On Time", then `coop mxiii`'s camp travel (experimental test command, untested in game; needs the zMXIII_P test pak; solo, co-op save only) |
| `coop lily signal quest\|travel\|next\|status` | The quest alone, the travel alone, the task of the step "On Time" is at (a test word), or one status line (the status on any save) |
| `coop lily talk prologue\|arrival\|finale [kit]` | One of Lily's talks by hand, in the game's subtitle box or, with `kit`, in the mod's own subtitles; `coop scene lily` is the prologue talk (same conditions as `coop lily signal`) |
| `coop lily hold on\|off` | The talks' reading holds on or off until the next Lua load (any save) |
| `coop fly on\|off`, `coop slowmo on\|off` | The game's [developer flight and slow motion](cut-eve.md#debug-flight-and-slow-motion-coop-fly-and-coop-slowmo): a third press of the space bar in the air flies (test commands, untested in game; on on a co-op save only) |
| `coop glide on\|off` | EVE's [cut glide](cut-eve.md#cut-glide-coop-glide) while Jump is held in the air (test command, untested in game; on on a co-op save only) |
| `coop shortcut` | List the [cut Load Shortcut menu's saves](cut-scenes-and-menus.md#cut-load-shortcut-saves-coop-shortcut) in `coop-link.log` (test command, untested in game, any save) |
| `coop shortcut load <map> <1-4>` | Write one of those saves, without its achievement list, as [co-op slot 5](cut-scenes-and-menus.md#loading-one-coop-shortcut-load) for Load Game (test command, untested in game; needs `shortcut_load=on`, typed twice within 10 s, at the title with co-op saves on; can unlock Steam achievements) |
| `coop devmenu [list\|<row>]` | The rows of the game's [developer menu](cut-scenes-and-menus.md#developer-menu-coop-devmenu-and-coop-devinfo) that still work: the list, or one row on EVE or the enemies near her (test command, untested in game; a row on a co-op save only) |
| `coop devinfo quest\|player\|off` | The game's [quest debugger or player info panel](cut-scenes-and-menus.md#developer-menu-coop-devmenu-and-coop-devinfo), opened or closed (test command, untested in game, any save) |
| `coop story [dump\|find]` | Write the story lines of the save object the running game holds to `StellarCoopStory.txt`, read only, or list the save-shaped classes and objects found ([story.md](story.md#the-live-dump); test command, any save) |
| `coop gift [send <item> [count]\|take [n]]` | The [cut mailbox as a gift box](cut-scenes-and-menus.md#cut-mailbox-coop-gift): what waits in yours, a gift of 1 to 10 consumables to your linked friend, or the gifts that wait put into your inventory (untested in game, co-op save on both sides) |
| `coop race record <name>\|cp\|save [laps]\|cancel` | Record a [Doro race](doro-races.md) track (untested in game) |
| `coop race start <name>\|quit` | Start a Doro race on that track as the host or alone (co-op save only), or leave it |
| `coop race look on\|off`, `coop race probe doro`, `coop race drive [probe\|off\|feed impulse\|struct\|<name> <value>]` | [Doro race](doro-races.md) test and tuning commands: the Doro look with no race, a Doro that plays each of its animations, the drive probe, and the driving values (test commands; `look on`, `probe doro` and `drive probe` on a co-op save only) |
| `coop fight on\|off\|status` | Shared enemies (experimental, on by default, co-op save only) |
| `coop fight probe\|record\|replay`, `coop fight test hp\|sh\|st <change>`, `coop fight test kill` | Shared enemies' solo test tools (experimental, co-op save only) |
| `coop fight pilot status\|probe\|on\|off`, `coop fight pilot test freeze\|cmc\|drive\|replay\|target\|exec` | [Same place](shared-enemies.md#same-place-experimental) (experimental, on by default) and its solo test steps |
| `coop fight pilot test bstart\|phase\|finish\|summon` | Solo tests of [shared bosses](shared-enemies.md#shared-bosses-experimental) on the boss copy of a replay (experimental) |
| `coop fight spawn probe` | Solo probe of [same spawns](shared-enemies.md#same-spawns-experimental) (experimental, co-op save only) |
| `coop quests on\|off\|status` | [Shared quests](playing-with-a-friend.md#shared-quests-experimental) (experimental, off by default, co-op save only) |
| `coop quests probe\|record\|replay` | Shared quests' solo test tools (experimental, co-op save only) |
| `coop quests force <number>` | As the guest, make the step that quest holds for your own kill, or for a place the game's tables cannot give, where you stand; type it twice within 10 s |
| `coop freeze <seconds>` / `coop freeze off` | Hold the [synced photo mode](playing-with-a-friend.md#synced-photo-mode)'s pause alone, 1 to 3600 s |
| `coop revive test` | Solo test of the [revive](playing-with-a-friend.md#revive-by-your-friend-experimental): at the death screen, call the game's in-place respawn on your EVE once (co-op save only, no session, with `coop loopback 0 0 0` running so that your life state is read) |
| `coop guide` | Open the [guide](interface.md#guide) on its first page, on the title screen or in the world |
| `coop ui reset` | Close the co-op menu and the chat box, and give the game its keys back at once |
| `coop ui off` | Remove the co-op menu, the chat box, the feed, the partner HUD, Night Operation's card and result panel, the guide and the co-op saves' question until the mod reloads |
| `coop saves probe` | Log what the mod reads of the save file name and the plan of the next copy pass; writes nothing |
| `coop saves convert` / `coop saves coop` | At the title: make the [co-op copies](playing-with-a-friend.md#co-op-saves); `coop` then switches the game to them |
| `coop saves main` | At the title: switch back to your own saves, while no co-op save has been loaded since the game started |
| `coop saves refresh <0-4>` | At the title, while the game uses your own saves: replace that slot's co-op copy, even one played in co-op, with a new copy of your save. Type it twice within 10 s; the old copy goes to `StellarCoopBackups` first |
| `coop saves export <0-4> <0-4>` | At the title, while the game uses your own saves or the co-op copies: write that co-op copy over that save of yours, to play it without the mod (untested in game). Type it twice within 10 s; your save goes to `StellarCoopBackups` first, and a co-op copy that holds the mod's items, stands in Matrix XIII or is a shortcut save is refused ([saves.md](saves.md#co-op-saves)) |
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
  reloads (game start or Ctrl+R) and rebuilds the ghost. It does not change `coop-settings.txt`. See [Looks](ghost.md#looks).
- `coop cns` prints one line: `CNS part on` (or `off (<error>)`), then the mod assets set aside after a crash, each with
  its outfit, or `none`. `coop cns reset` clears both and builds the ghost again. See [When a mod asset
  fails](ghost.md#when-a-mod-asset-fails).

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
  reason (`protocol` for a file made under another protocol, which includes every file made before protocol 19). It
  then plays the file in a loop as the remote side, each pose re-stamped as if sent now, until `coop replay off`, which
  removes the ghost. The generation, map and positions stay as recorded: the ghost wears the recorded outfit and walks
  where you walked, with no offset, and the map gate applies.
- During `coop loopback` with no friend linked, a chat line you send comes back as your friend's, and your own HP,
  shield and gauges stand in for theirs on the partner card (`mate=` in `coop status`).
- The loopback and the replay never run together. Either one replaces a linked friend until it is off: nothing is sent
  to the friend meanwhile, what they send is ignored, and their ghost is removed. When it stops, you are linked again:
  your table goes to them at once, and theirs comes back within 5 s: their game sends it again when your poses reach
  them after the gap. A recording can run at the same time as either one.

See [internals/architecture.md](internals/architecture.md#loopback-record-and-replay) for the parts of the pipeline each one tests.

### Commands that need a co-op save

`coop no` (the probe) and `coop recruiter` (the cut recruiter) are research previews of the cut Night Operation mode,
not a playable mode. They run only on a [co-op save](playing-with-a-friend.md#co-op-saves) and need preparation first: read
[night-operation-previews.md](night-operation-previews.md) before you use them. Otherwise they stop with:

```
STOP: coop no runs only on a co-op save (INSTALL.md: Co-op saves); now <the slot line>
```

(`now no slot status` without the native part.)

`coop nightop`, Night Operation's run and its shop, and `coop challenge`, the challenges, run only on a co-op save too,
with the same `STOP:` line under their own names, except `coop nightop stop` and `coop challenge stop`, which work on
any save. See [night-operation.md](night-operation.md#the-solo-run-coop-nightop) and
[Challenges](challenges.md).

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
  open (see [night-operation-shop.md](night-operation-shop.md#status-lines)). `coop nightop buy` lists the points your runs
  gave and the seven items, and `coop nightop buy <n> [count]` buys 1 to 10 of item n into the co-op save. Items 5 and
  6, the cut Burst and Beta Stimpacks, need table rows the native part adds with the Lion's (see
  [Cut boss](cut-enemies.md#cut-boss-coop-lion)), and item 7, the cut [Shock Bolt](night-operation-shop.md#cut-ammo-shock-bolt) ammo, rows of its own: a buy
  of one asks for them first, and the screen asks for both. Your points are in `coop-night-<steamid>-<index>.txt` in the
  mod folder, one file per Steam ID and co-op slot. See [night-operation-shop.md](night-operation-shop.md).
- `coop challenge range` (or `coop challenge 5`) starts the Shooting Range: three rounds of 3, 4 and 5 of the game's
  target dummies, all around EVE, in 2:00. It is made for the drone's ranged mode, which needs the gun the story
  unlocks; the sword reaches the dummies too. Alone it needs no Steam session; in a session the host starts it for
  both players, as a co-op Night Operation run. Its score also shows on the cut test widget `WB_ShootingTrainingTest`.
  See [challenges.md](challenges.md#shooting-range).
- On a co-op save, Roxanne in Xion offers Night Operation (Easy, Normal, Hard) and its supplies in her dialogue. See
  [night-operation-shop.md](night-operation-shop.md#night-operation-at-roxannes).

The ghost, the link and every other command except `coop fight` (below), `coop race start`, `coop race look on`,
`coop race probe doro` and `coop race drive probe` (see [Doro races](doro-races.md)), `coop leviathan show`,
`coop leviathan cam` when it turns the camera on (and the same two in the six other
[viewer commands](cut-enemies.md#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril)), `coop lion`, `coop lion intro`,
`coop lion control`, `coop gardener fight` with no word, `intro`, `half` or `skulling`, `coop tendril fight` with no
word, `coop chainspin`, a scene of `coop scene`, `coop fly on`, `coop slowmo on`, `coop glide on`, a row of
`coop devmenu` and `coop gift` (see [cut-scenes-and-menus.md](cut-scenes-and-menus.md#cut-mailbox-coop-gift)) run on any save.
`coop fight pilot` runs on any save too, since same place only moves enemies while shared enemies run.

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
[Developer menu](cut-scenes-and-menus.md#developer-menu-coop-devmenu-and-coop-devinfo)). A `coop gift send` caught after the items left your
inventory and before the gift reached your mailbox file stops there, and those items are lost. Gift lines from your
friend that arrive after `coop off` are dropped without an answer. Afterwards only `coop status` and `coop report`
answer. Every other command answers `STOP: coop off is active until the game restarts`,
and so do the menu, host and leave keys. The race key does nothing.

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

- Steam: `mod=<version> proto=19 steam=<waiting|ready>`, then the Steam ID, app id, game build, overlay, relay
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
  host's last answer ([Following the host](playing-with-a-friend.md#following-the-host)).
- Pose path: `engine=on` (then `loopback=on <delay> <jitter> <loss>` or `loopback=waiting` until EVE's capture comes,
  `record=on`, `replay=on`, `remote=<generation> <count> <loopback|replay|peer>`), or `engine=off reason=<why>`; then
  `warp=<idle|busy> me=<n>` (a respawn or a warp under way, and your EVE's id, for the revive), `travel=<state>
  travel_calls=<n>` (the last travel's state: `idle`, `pending`, `warping`, `arrived` or `refused:<why>`, and the travel
  requests handled so far), `anim=<state> anim_id=<n>` (the last `coop emote` clip the native part took and what
  became of it: `idle`, `playing`, `ended`, `ended:weight`, `stopped`, `refused:<why>` or `fault`, see
  [Emotes](cut-eve.md#emotes-coop-emote)), `items=<ask> <count>` or `items=<ask> none <why>` (the answer to
  [`coop gift`](cut-scenes-and-menus.md#cut-mailbox-coop-gift)'s last inventory read, by its number; why is `unpinned`, `noeve`, `nomanager`,
  `nobucket` or `unread`), and `nightop=on` or `nightop=rule` while the probe's poller runs.
- Activated camps: `activated=<n>:<camp>,<camp>,...` lists the camps of the game's camp table (simple and full camps,
  phone booths, tetrapods) that the game's own camp list would show for this save, read every 2 s while you play,
  followed by `rested=<camp>`, the camp where EVE respawns (that of her last rest or fast-travel arrival), when the
  mod knows it. `activated=none:<why>` means there is no read now: `flow` or `phase` at the title or during a load,
  `fault` once a fault stopped the read until the game restarts, and another word for a part of the game the mod found
  missing. After a fault, `coop-link.log` has `camps read off: fault 0x... at StellarCoop.dll+0x... reading 0x...;
  coop travel probe and coop mxiii leave refused until the game restarts`, once.
  [`coop travel probe`](playing-with-a-friend.md#following-the-host) and `coop mxiii leave` take only camps from this list.
- Save slot: `slot=<coop|main|none|unknown> index=<n|?> marker=<n|none|bad|?> saves=<coop|main|off|?>` (see
  [saves.md](saves.md#co-op-saves)). `saves=` names the save files the game uses: `main` for your own,
  `coop` for the co-op copies (`StellarBladeCoop00.sav` to `04`), `off` when the mod cannot read the file name (another
  game build, or a check failed), and `?` before the first read or once the name moved in the game's memory (no switch
  until the game restarts). `coop-link.log` logs each change as `save name: saves=<value>`, with the reason for `off`
  and `?`. After `coop off` it keeps the last value read, since the game keeps that file name until it exits.
- Co-op save copies: `convert=<idle|busy <done>/<jobs>|done|error:<why>>`, the last copy pass (`idle` before any).
- Shared enemies: `fight=on mode=<on|probe|record|replay> ...` with its counts, `fight=waiting mode=<mode> why=<what it
  waits for>`, `fight=stopped why=<why>` or `fight=off`, with `her=<state>` while a friend is linked (see [Shared
  enemies](shared-enemies.md#shared-enemies-experimental)). While it runs, the line ends with `boss=<0|1>` (a boss fight on your side),
  `battle=<n>` (enemies in battle within 30 m of your EVE) and `epoch=<zone>/<n>/<resets>` (same spawns' zone and epoch,
  and how often your own zone reset this run).
- Same place: `pilot=on piloted=<n>`, `pilot=off why=<why>`, `pilot=stopped` or `pilot=refused why=<why>` (see
  [Same place](shared-enemies.md#same-place-experimental)).
- Shared quests: `quests=off`, `quests=waiting mode=<mode> why=<friend|save|game>`, `quests=on mode=<mode>
  role=<role> partner=<on|off>` or `quests=stopped` (see [Shared quests](playing-with-a-friend.md#shared-quests-experimental)), then the last 8
  quest notices as `quest_note=<n> <kind> <number> <name> <zone or ->` and the last `coop quests status` answer as
  `quests_status=<n> <line>` lines.
- Photo mode: `photo=<0|1|s|c> peer_photo=<0|1|s|c> frozen=<0|1> sync=<both|notice|off>`: yours and your friend's (`s`
  for selfie mode, `c` on the host while a cutscene plays: the [cutscene wait](playing-with-a-friend.md#cutscene-wait)), whether your game holds
  the photo pause (`coop freeze` holds it too), and the `photo_sync` your friend gets (`notice` when your game cannot
  pause).
- Last event: `last=<the last coop-link.log event>`.
- Ghost: `ghost=on parts=<n> leaders=<n> basesuit=<0|1> left_out=<n> table=<generation> source=<source>
  collide=<on|off|failed>`, `ghost=waiting`, `ghost=hidden map` or `ghost=off`, plus `stray_parts=<n>` if ghost parts
  that are not this load's ghost stand in the world. Once the [solid partner](ghost.md#solid-partner-experimental)'s capsule
  exists, `collide=` adds `solid=<0|1>` and `changes=`, the times it turned solid and the times each rule let your EVE
  through (`a` hidden or off, `b` overlap, `c` height, `d` movement mode, `e` 2 s of contact, `g` your friend down).

Each changed status line, except the per-peer ones, the `fight=` line, the `mate=` and `life=` lines and the `night=`
line (Night Operation's run logs each one as an `[NR]` line), also goes to `UE4SS.log` as `[StellarCoop] link: ...`.
Each load logs the save slot as `link: slot=...`.
