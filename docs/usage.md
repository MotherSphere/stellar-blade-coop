# Keys and console commands

To install the mod, see [INSTALL.md](../INSTALL.md). The other player pages are listed in the
[documentation index](README.md), and what happens behind each feature is in [How it works](README.md#how-stellar-blade-online-works). The mod's
`coop shortcut` messages, its `coop-settings.txt` and some code comments still name this page for sections that have
moved; [Sections that moved](#sections-that-moved), at the end, gives the new place of each one.

Close the game before you change any file in the mod folder.

## Keys

The keys work with or without the console. They need the native part (`StellarCoop.dll`).

| Key (default) | Action | Console equivalent |
| --- | --- | --- |
| F5 | Open or close the [co-op menu](players/interface.md#co-op-menu); its first row hosts a session. Within 3 m of a camp phone booth, open the [co-op line](players/interface.md#co-op-line) instead. In the [SBO lobby](online/lobby.md#the-lobby-menu), open the lobby menu, or sit on a hall seat within 1.5 m that has no chair | (none) |
| View held 1 s, on a [controller](players/interface.md#controller) | Open or close the co-op menu, the co-op line at a booth, or the lobby menu in the SBO lobby | (none) |
| LB, RB, on a controller | Change the tab of the SBO lobby's Settings screen or of the [Sessions screen](players/interface.md#sessions-screen) | (none) |
| RB or E on the Settings tab of the game's pause menu, or a click on its Online tab | Close the pause menu and open the co-op menu ([Pause menu](players/interface.md#pause-menu)) | (none) |
| Y, on a controller | Refresh the Sessions screen's list, or stop the search that runs | `coop list public\|friends` |
| F6 | Show the status: one line on screen (see [Notices](players/interface.md#notices)) and in `UE4SS.log` | (a short form of `coop status`) |
| F7 | As the guest, travel to where the host last stood on solid ground (from another map, through the camp nearest him first), or cancel the travel that `follow_host=always` is about to start ([Following the host](players/playing-with-a-friend.md#following-the-host)). On the death screen, while its offer shows, get up in place and go back to a living friend on your map, or cancel `always`'s way back ([Back to a friend after a death](players/playing-with-a-friend.md#back-to-a-friend-after-a-death)) | `coop travel host` |
| F8 | Leave the session | `coop leave` |
| F9 | While you record a [Doro race](online/modes/race.md) track, set a checkpoint where EVE stands; nothing otherwise | `coop race cp` |
| F3 | Put EVE on the [bike](vehicles/bike.md) or take her off it; a refusal shows its reason on screen | `coop bike` |
| D-pad Right held 1 s, on a controller | The same as F3, in a world with none of the mod's screens or the game's menus open | `coop bike` |
| F4 | Bring the NIKKE rifle out or put it away ([gun mode](fight/gunmode.md), experimental; without the optional `zNGMSpike_P` pak it shows only the notice "Gun mode: rebuilding"). `gun_key` in `coop-settings.txt` sets the key. G is left to Stellar Blade, which binds it to a menu action | `coop gun` |
| A tap of D-pad Right (released within 0.4 s), on a controller | The same as F4 | `coop gun` |
| Enter | During a session or in the SBO lobby, open the [chat](players/interface.md#session-chat) box, then send a line; Esc closes the box | (none) |
| none | Host a session at once, or open the Steam invite dialog again while you host (`host_key`) | `coop host` |

You can change F3, F4, F5, F6, F7, F8 and F9 in the menu's Options page or in [coop-settings.txt](players/settings.md#coop-settingstxt).
Only the file sets `host_key`. A key passes its action to the game thread, where the same checks as for the console
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
| `coop host` | Open the [Create a session screen](players/interface.md#create-a-session-screen), as the menu's Host a session row does. Where it cannot open, host an online session at once as `who_can_join`, `friends_ask` and `max_players` say: a Public or Friends only session, an Invitation session with a [join code](players/playing-with-a-friend.md#join-codes), or a Private one nobody can join |
| `coop host public\|friends\|invitation\|closed` | Host at once with that word in place of `who_can_join`; `friends_ask` applies under `public` and `invitation` |
| `coop invite` | Open the Steam invite dialog again while you are in a lobby |
| `coop join` | Join the first Steam friend found in a Stellar Blade lobby |
| `coop join <lobby id>` | Join that lobby (digits only) |
| `coop join <code>` | Join the lobby of that [join code](players/playing-with-a-friend.md#join-codes), in capitals or not, with or without the dash |
| `coop list public\|friends` | Search the session list's Public online sessions, or your Steam friends' ones |
| `coop list` | Print the last session list's rows, numbered; with no list yet, search the Public sessions |
| `coop join <row>` | Join the online session of that row of `coop list` (1 to 99) |
| `coop copy` | Put your join code on the clipboard while you host with one (the menu's Copy my code row) |
| `coop allow <SteamID>` / `coop deny <SteamID>` | Let in or refuse the player who is not your Steam friend and waits for your answer |
| `coop remove <SteamID>` | Remove a player from the session you host and put them on your [block list](players/playing-with-a-friend.md#block-list): they cannot come back to any game you host |
| `coop block <SteamID>` | Put a player on your block list without a session; a player in the game you host is removed as well |
| `coop unblock <SteamID>`, `coop unblock all` | Take one player off your block list, or empty it |
| `coop blocked` | Print how many players your block list holds (the file keeps only hashes, so it cannot name them) |
| `coop leave` | Leave the session (F8) |
| `coop match search\|create <mode>`, `coop match cancel`, `coop match end`, `coop match join <code>`, `coop match leave` | A [match lobby](online/lobby.md#search) of up to 8 players (experimental). The modes are `scoreattack` and `ffa`. A `scoreattack` round plays a challenge in the lobby room ([Score attack](online/modes/scoreattack.md)). An `ffa` round's start does not take anyone to an arena yet. `search` joins an open public lobby of that mode, or hosts one when none is open; `create` hosts a private one that players join with its [join code](players/playing-with-a-friend.md#join-codes); `cancel` stops a search; `end` ends the round you host; `join <code>` and `leave` work like `coop join <code>` and `coop leave`. `search` and `create` are refused while you are in a lobby. They run from the console anywhere and on any save, not only in the SBO lobby; outside it they have not been tested in game |
| `coop mute <SteamID>` / `coop unmute <SteamID>` | Drop that player's chat lines, or show them again, in any lobby until the game closes (experimental). The `member=` lines of `coop status` start with each member's SteamID, masked to its last 4 digits, which these commands take too |
| `coop travel host` | As the guest, travel to where the host last stood on solid ground (F7), or cancel the travel that `follow_host=always` is about to start ([Following the host](players/playing-with-a-friend.md#following-the-host)). On the death screen it does what F7 does there |
| `coop travel spot [<world>] <x> <y> <z>` | Solo test of the spot warp: the game's own position warp to that place in whole centimetres, yaw 0, with no camp and no session; with a world of the game's story worlds (`core/worlds.lua`), that world's name goes into the warp's record. The result is in `UE4SS.log` and `coop-link.log` ([The spot warp](online/group-internals.md#the-spot-warp)) (test command, co-op save only) |
| `coop travel probe <camp>` | Solo test of the follow's travel: the game's own fast travel to one of its 120 camps that your save has activated (the `activated=` line of `coop status`), with no session and no host's answer; any other camp is refused, see [Following the host](players/playing-with-a-friend.md#following-the-host) (test command, co-op save only) |
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
| `coop wear [<name>\|off [hair\|suit]]` | Put a [cut hair or suit](eve/eve.md#cut-hairs-and-suits-coop-wear) on your EVE (display only, untested in game), or give the game's back |
| `coop lines [<name>\|stop]` | Show the subtitles of a [scene cut before it was voiced](story/scenes.md#cut-scene-lines-coop-lines) in the chat's feed, or play unused voice takes, or end it (untested in game) |
| `coop emote [list\|<name>\|off]` | Play one of [EVE's clips](eve/eve.md#emotes-coop-emote) (a photo-mode pose held until she moves, a wave, a clip of the Cut category; untested in game), list them or end it |
| `coop bike` | Put EVE on the [bike](vehicles/bike.md) or take her off it, on any save (untested in game) |
| `coop bike status` | The bike's preload, whether it is on EVE, whether she rides, its four riding values, where it is [parked](vehicles/bike.md#where-the-bike-stays) (`parked on <map>`, with `<n> m away` on her map, or `no place yet`) |
| `coop bike tune [<name> <value>]` | The four [riding values](vehicles/bike.md#coop-bike), or one changed for your next rides until the mod reloads |
| `coop gun [status]` | Alone: bring the NIKKE rifle out or put it away, as `gun_key` does ([gun mode](fight/gunmode.md), experimental). `status` prints one line: whether the rifle is out, firing mode or moving, the key and the shots fired, as `gun mode on (moving), key F4, 12 shots` |
| `coop loopback <delay ms> <jitter ms> <loss %>` | Run your own ghost through a simulated network on one PC |
| `coop loopback off` | Stop the loopback |
| `coop record` / `coop record off` | Record what you send (table and poses) to `coop-record.bin` |
| `coop replay` / `coop replay off` | Play `coop-record.bin` back as a ghost, in a loop |
| `coop nightop [start [easy\|normal\|hard\|nightmare] [noaggro\|nomove]\|stop]` | [Night Operation's run](online/modes/nightop.md#the-solo-run-coop-nightop) at one of four [levels](online/modes/nightop.md#levels), solo or, started by the host at his level, [for both players](online/modes/nightop.md#the-co-op-run) (one solo run in game, on 2026-10-28, tracked none of its monsters and spawned some inside walls; the fixes for the tracking and for the spawn points are untested in game; co-op save only; `stop` on any save) |
| `coop nightop revive` | In a co-op run with `revive=on`, while your EVE is down: revive her yourself, a few times a run ([Down and revive](online/modes/nightop.md#down-and-revive)) (untested in game, co-op save only) |
| `coop nightop shop` | Night Operation's [reward shop](online/modes/nightop-shop.md#the-shop-screen-coop-nightop-shop) in the game's own shop screen, your points as Beta Seeds, with its seven items (two cut stimpacks and the cut [Shock Bolt](online/modes/nightop-shop.md#cut-ammo-shock-bolt) ammo among them; the Shock Bolt only once EVE's gun can fire it) (the screen opened in game; buying from it is untested; co-op save only) |
| `coop nightop buy [<n> [count]]` | The same shop from the console: your points and its seven items, or a buy of 1 to 10 of one of them (untested in game, co-op save only) |
| `coop scoreattack [status\|pick <challenge>]` | [Score attack](online/modes/scoreattack.md#settings-and-commands) (untested in game): alone or `status`, one line with the host's challenge pick, your last round, its state and its ranking; `pick random`, a challenge's name or its number (1 to 5) sets the pick as the lobby menu's Challenge row does. Only the host's pick counts. Needs the Steam link |
| `coop fish [status\|start [<minutes>]\|stop]` | [Fishing tournament](online/modes/fishing.md#settings-and-commands) (untested in game): alone or `status`, one line with your last tournament, its state, its clock, the board and the ranking; `start` on the host of an online session starts one of 10 minutes, or of 1 to 60, for every player past the handshake; `stop` on the host cancels it in every game. Needs the Steam link |
| `coop challenge [<name>\|stop]` | [Challenges](online/modes/challenges.md): the list with each best run, a start by name or number (1 to 5), or the end of the run that is on (untested in game, co-op save only; solo but the [Shooting Range](online/modes/challenges.md#shooting-range), which the host can start for both players; `stop` on any save) |
| `coop no [heal\|rule\|spawnpt\|actor]` | Night Operation probe (research preview, co-op save only) |
| `coop recruiter [off]` | Night Operation recruiter (research preview, co-op save only). He also appears by himself at each Xion load, on any save; `off` keeps him away until the next one |
| `coop scene [emil\|orcal\|stop]` | Play a [cut scene](story/scenes.md#cut-scenes-coop-scene) through the game's cutscene player (untested in game, co-op save only), list the scenes or stop the one that plays |
| `coop leviathan`, `coop gardener`, `coop tendril`, `coop mann`, `coop nier`, `coop orcal`, `coop enya`, each with `[list]\|show\|move\|skin\|cam\|play\|off` | Read a [cut model](fight/bosses.md#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril)'s assets, or show it in front of EVE with a [free camera](fight/bosses.md#free-camera) to film it, one model at a time and no enemy spawned (test commands; `show` and the camera turned on on a co-op save only) |
| `coop lion [intro]\|rows\|control`, `coop lion brain skulling\|lurker`, `coop lion unfreeze [init]` | The [cut Lion](fight/bosses.md#cut-boss-coop-lion) as an enemy to fight (test command; fought in game on 2026-10-24): spawn one, with its entrance first; add its rows only; spawn an Antlion through the same call; pick the tree of the next Lions; put back the engine switches that can freeze its mesh (spawns on a co-op save only) |
| `coop gardener fight [intro\|half\|skulling\|rows]` | The [cut Gardener](fight/bosses.md#cut-enemy-coop-gardener-fight) as an enemy to fight (test command, untested in game): spawn one, with its entrance first, at half size, or with the Lion's tree; add its rows only (spawns on a co-op save only) |
| `coop tendril fight [rows]` | The [cut Tendril](fight/bosses.md#cut-enemy-coop-tendril-fight) as an enemy to fight (test command, untested in game): spawn one, with the Shows of its attacks built in memory first; add its rows and build its Shows only (spawns on a co-op save only) |
| `coop chainspin` | EVE's [cut Tachy Mode ChainSpin](eve/eve.md#cut-tachy-skill-coop-chainspin), started once while she is in Tachy Mode (test command, untested in game, co-op save only) |
| `coop mxiii` | A camp travel into the [cut Matrix XIII dungeon](world/matrix13.md) and a camp there (experimental test command; the travel arrived in game with test pak v2 after a reload, the rows at the title are untested; needs the v5 zMXIII_P test pak, which the mod does not ship; solo, co-op save only) |
| `coop mxiii 30` | The same with a travel to a second camp, in the dungeon's third zone (experimental test command, untested in game; needs the v5 test pak; solo, co-op save only) |
| `coop mxiii leave` | The way out of Matrix XIII: a travel back to the camp where EVE respawned before `coop mxiii`, or to another camp your save has activated (test command, untested in game; solo, co-op save only) |
| `coop lily signal` | [Lily's signal](world/lily-signal.md) by hand: the mod's quest "On Time", then `coop mxiii`'s camp travel (experimental test command, untested in game; needs the zMXIII_P test pak; solo, co-op save only) |
| `coop lily signal quest\|travel\|next\|status` | The quest alone, the travel alone, the task of the step "On Time" is at (a test word), or one status line (the status on any save) |
| `coop lily talk prologue\|arrival\|finale [kit]` | One of Lily's talks by hand, in the game's subtitle box or, with `kit`, in the mod's own subtitles; `coop scene lily` is the prologue talk (same conditions as `coop lily signal`) |
| `coop lily hold on\|off` | The talks' reading holds on or off until the next Lua load (any save) |
| `coop fly on\|off`, `coop slowmo on\|off` | The game's [developer flight and slow motion](eve/eve.md#debug-flight-and-slow-motion-coop-fly-and-coop-slowmo): a third press of the space bar in the air flies (test commands, untested in game; on on a co-op save only) |
| `coop glide on\|off` | EVE's [cut glide](eve/eve.md#cut-glide-coop-glide) while Jump is held in the air (test command, untested in game; on on a co-op save only) |
| `coop shortcut` | List the [cut Load Shortcut menu's saves](cutmenus/menus.md#cut-load-shortcut-saves-coop-shortcut) in `coop-link.log` (test command, untested in game, any save) |
| `coop shortcut load <map> <1-4>` | Write one of those saves, without its achievement list, as [co-op slot 5](cutmenus/menus.md#loading-one-coop-shortcut-load) for Load Game (test command, untested in game; needs `shortcut_load=on`, typed twice within 10 s, at the title with co-op saves on; can unlock Steam achievements) |
| `coop devmenu [list\|<row>]` | The rows of the game's [developer menu](cutmenus/menus.md#developer-menu-coop-devmenu-and-coop-devinfo) that still work: the list, or one row on EVE or the enemies near her (test command, untested in game; a row on a co-op save only) |
| `coop devinfo quest\|player\|off` | The game's [quest debugger or player info panel](cutmenus/menus.md#developer-menu-coop-devmenu-and-coop-devinfo), opened or closed (test command, untested in game, any save) |
| `coop story [dump\|find]` | Write the [story dump](dev/story-dump.md) to `StellarCoopStory.txt` in the mod folder: the story lines of the game's live save object, or with `find` a list of the objects that may hold them; a `coop-story.txt` file in the mod folder asks the same while a world is loaded (test command, untested in game, any save, read only) |
| `coop gift [send <item> [count]\|take [n]]` | The [cut mailbox as a gift box](cutmenus/menus.md#cut-mailbox-coop-gift): what waits in yours, a gift of 1 to 10 consumables to your linked friend, or the gifts that wait put into your inventory (untested in game, co-op save on both sides) |
| `coop race record <name>\|cp\|save [laps]\|cancel` | Record a [Doro race](online/modes/race.md) track (untested in game) |
| `coop race start <name>\|quit` | Start a Doro race on that track as the host or alone (co-op save only), or leave it |
| `coop race look on\|off`, `coop race probe doro`, `coop race drive [probe\|off\|feed impulse\|struct\|<name> <value>]` | [Doro race](online/modes/race.md) test and tuning commands: the Doro look with no race, a Doro that plays each of its animations, the drive probe, and the driving values (test commands; `look on`, `probe doro` and `drive probe` on a co-op save only) |
| `coop fight on\|off\|status` | Shared enemies (experimental, on by default, co-op save only) |
| `coop fight probe\|record\|replay`, `coop fight test hp\|sh\|st <change>`, `coop fight test kill` | Shared enemies' solo test tools (experimental, co-op save only) |
| `coop fight pilot status\|probe\|on\|off`, `coop fight pilot test freeze\|cmc\|drive\|replay\|target\|exec` | [Same place](fight/enemies.md#same-place-experimental) (experimental, on by default) and its solo test steps |
| `coop fight pilot test bstart\|phase\|finish\|summon` | Solo tests of [shared bosses](fight/enemies.md#shared-bosses-experimental) on the boss copy of a replay (experimental) |
| `coop fight spawn probe` | Solo probe of [same spawns](fight/enemies.md#same-spawns-experimental) (experimental, co-op save only) |
| `coop pvp on\|off\|status` | The [PvP test](online/lobby.md#the-pvp-test) with your linked friend, who types it too: a stand-in at their ghost takes your hits for their game, down to 1 HP (test command, untested in game; needs `pvp_spike=on` and `shared_enemies=off`, co-op save only) |
| `coop sbo enter\|leave\|status` | The [SBO lobby](online/lobby.md) by hand: `enter` saves the co-op game and takes you to the lobby, as the recruiter's Join does; `leave` brings you back to where you stood; `status` prints one line (test command, untested in game; needs `sbo_lobby=on`, co-op save only) |
| `coop sbo hop\|back\|view [set]\|seq <alias>\|parts` | The SBO lobby's test commands: `hop` goes from the lobby to the NK_Boss_Scarlet arena when no match lobby is open, and `back` returns to the lobby from there; `view` prints the camera's location, rotation and FOV, and `view set` uses that view for the lobby menu's camera until the mod reloads; `seq` plays one of Xion's light sequences, `Xion_10_E_Seq_011`, `_013`, `_012` or `_019`, in the lobby; `seq done` and the native `called` line only say that Stellar Blade was asked, because the game first checks the row's condition against EVE's save and plays nothing, with no log line, when it fails or when that sequence already plays (`_011` plays only before Xion's phase 2, `_019` only once `Quest_Epic_11` is done); `parts` makes each Stellar Blade widget part of the lobby screens once and logs the result (test command, untested in game; needs `sbo_lobby=on`, co-op save only) |
| `coop quests on\|off\|status` | [Shared quests](players/playing-with-a-friend.md#shared-quests-experimental) (experimental, on by default, co-op save only) |
| `coop quests probe\|record\|replay` | Shared quests' solo test tools (experimental, co-op save only) |
| `coop quests force <number>` | As the guest, make the step that quest holds for your own kill, or for a place the game's tables cannot give, where you stand; type it twice within 10 s |
| `coop world on\|off\|status` | The [shared world](world/objects.md) (experimental, on by default): `on` and `off` until the mod reloads, whatever `shared_world` says; `status` prints the `world=` line |
| `coop daynight [on\|off\|status\|hour <h>]` | The [day and night cycle](world/daynight-internals.md) (on by default, untested in game; a test tool, never written to `coop-settings.txt`): alone or `status`, one line with the request and its reason, the map's row, the native part's hour and sun and the real minutes until the next night; `off` gives Stellar Blade's own light and `on` the clock again, until another word or a Lua reload; `hour <h>` pins the hour, 0 to under 24 with decimals (`13.5` is 13:30), until `on`, `off` or a Lua reload, refused while `daynight=off`; any save |
| `coop teamshop` | The [team shop](world/teamshop.md): the game's own shop screen with the outfits the SBO team sells for gold (untested in game, co-op save only) |
| `coop scenes on\|off\|status` | [Story together](story/together.md) (experimental, on by default): `on` and `off` until the mod reloads, whatever `shared_story` says; `status` prints the `story=` line |
| `coop freeze <seconds>` / `coop freeze off` | Hold the [synced photo mode](players/playing-with-a-friend.md#synced-photo-mode)'s pause alone, 1 to 3600 s |
| `coop revive test` | Solo test of the [revive](players/playing-with-a-friend.md#revive-by-your-friend-experimental): at the death screen, call the game's in-place respawn on your EVE once (co-op save only, no session, with `coop loopback 0 0 0` running so that your life state is read) |
| `coop guide` | Open the [guide](players/interface.md#guide) on its first page, on the title screen or in the world |
| `coop keys reset [<name>\|all]` | Put one key back to its default (`menu`, `host`, `status`, `leave`, `follow`, `race` or `bike`), or every key with `all` or no name, as the [co-op menu's Controls rows](players/interface.md#options) do. A key whose default another action holds stays as it is |
| `coop ui reset` | Close the co-op menu and the chat box, and give the game its keys back at once |
| `coop ui off` | Remove the co-op menu, the chat box, the feed, the partner HUD, Night Operation's card and result panel, the guide and the co-op saves' question until the mod reloads |
| `coop saves probe` | Log what the mod reads of the save file name and the plan of the next copy pass; writes nothing |
| `coop saves convert` / `coop saves coop` | At the title: make the [co-op copies](players/playing-with-a-friend.md#co-op-saves); `coop` then switches the game to them |
| `coop saves main` | At the title: switch back to your own saves, while no co-op save has been loaded since the game started |
| `coop saves refresh <0-4>` | At the title, while the game uses your own saves: replace that slot's co-op copy, even one played in co-op, with a new copy of your save. Type it twice within 10 s; the old copy goes to `StellarCoopBackups` first |
| `coop saves export <0-4> <0-4>` | At the title, while the game uses your own saves or the co-op copies: write that co-op copy over that save of yours, to play it without the mod (untested in game). Type it twice within 10 s; your save goes to `StellarCoopBackups` first, and a co-op copy that holds the mod's items, stands in Matrix XIII or is a shortcut save is refused ([players/saves.md](players/saves.md#co-op-saves)) |
| `coop off` | Stop everything until the game restarts |

### Session commands

- `coop host` works like the menu's Host a session row: it opens the Create a session screen, whose Start hosts. The
  screen opens in a world while you are in no lobby. Anywhere else `coop host` asks the native part at once: while you
  host, it opens the invite dialog again, as `coop invite` does, or says `Nobody can join a private session.` in a
  Private session. A guest's host request is refused. With a word (`coop host closed`) it hosts at once with that word
  in place of `who_can_join`; any other word is refused. While you host, a word (the one typed, else `who_can_join`)
  other than your session's is refused with the notice `You already host a session: leave it first to host with
  another Who can join.` Leave with `coop leave`, then host again. Under `public` and `invitation`, `friends_ask=on` makes your
  Steam friends wait for your answer too. The request ends with `max_players`, the players the lobby holds (2 to 4),
  for example `host public ask 4`.
- `coop list public` and `coop list friends` start a search, one at a time and 5 s apart at least. The search is
  refused in a lobby and while a match search runs, with the reason in the log and the feed. The rows come a few
  seconds later. `coop list` then prints them on one line, best ping first:
  `list public done, 2 rows: 1. <host> 1/4 45 ms b07 WLB10_Camp_01 rules ebwsqr200 (Steam friend) | 2. ...`. A `-`
  stands for a ping or a region the row lacks. The rules word has a letter for each session rule on (e shared
  enemies, b bosses, w shared world, s story together, q shared quests, r revive), then the
  boss HP scale in percent. `coop join 1` joins the first row: a player who is not the host's Steam friend then waits
  for the host's answer, as does any player when the host has `friends_ask=on`.
- `coop join` and `coop join <lobby id>` do not wait for a save to load, unlike an accepted invite. Without an id it
  joins the first friend found in a Stellar Blade lobby; the log says `no friend is in a Stellar Blade lobby` when
  there is none. A lobby id is digits only, and any other text is taken for a join code.
- `coop leave` works like F8.
- `coop report` writes `coop-report.txt` in the mod folder: versions, the save folder, DLLs loaded from other mods, the
  status, a summary of save folder changes and the last 100 events. Its SteamIDs and join codes are masked, as in the
  logs (see [Which logs to send](players/troubleshooting.md#which-logs-to-send)).
- `coop allow`, `coop deny`, `coop remove`, `coop block`, `coop mute` and `coop unmute` take a full SteamID, or the 4
  digits the logs show after `***` for one. With the 4 digits they act on the one player in your lobby whose SteamID
  ends in them. When two players do, use the full SteamID from `coop-status.txt` in the mod folder, which keeps it
  whole. `coop unblock` takes the 4 digits only for a player blocked in this game run: `coop-status.txt` lists each
  one whole on a `block=<SteamID> <name>` line. For a player blocked in an earlier game run it needs the full SteamID,
  which the player can give you ([Block list](players/playing-with-a-friend.md#block-list) says where they find it).

### Ghost commands

- `coop puppet` turns the ghost on or off by hand. The ghost turns on automatically when a session starts (the link
  going from none to host or guest). If you turn it off with `coop puppet`, it stays off until the next session.
  Turning it on draws nothing at first: it publishes your EVE's capture, and a ghost is drawn once a table comes back
  from a linked friend, the loopback or a replay.
- `coop basesuit` draws the body and hair on the base suit whatever the table names, and rebuilds the ghost. Run it
  again to go back to each part's own mesh.
- `coop look` with no arguments prints the same `look:` line that each load logs, for example
  `look: cloth=on dyes=off effects=off`. `coop look <cloth|dyes|effects> <on|off>` changes one look until the mod
  reloads (game start or Ctrl+R) and rebuilds the ghost. It does not change `coop-settings.txt`. See [Looks](online/partner.md#looks).
- `coop cns` prints one line: `CNS part on` (or `off (<error>)`), then the mod assets set aside after a crash, each with
  its outfit, or `none`. `coop cns reset` clears both and builds the ghost again. See [When a mod asset
  fails](online/partner.md#when-a-mod-asset-fails).

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
  reason (`protocol` for a file made under another protocol, which includes every file made before protocol 26). It
  then plays the file in a loop as the remote side, each pose re-stamped as if sent now, until `coop replay off`, which
  removes the ghost. The generation, map and positions stay as recorded: the ghost wears the recorded outfit and walks
  where you walked, with no offset, and the map gate applies.
- During `coop loopback` with no friend linked, a chat line you send comes back as your friend's, and your own HP,
  shield and gauges stand in for theirs on the partner card (`mate=` in `coop status`).
- The loopback and the replay never run together. Either one replaces a linked friend until it is off: nothing is sent
  to the friend meanwhile, what they send is ignored, and their ghost is removed. When it stops, you are linked again:
  your table goes to them at once, and theirs comes back within 5 s: their game sends it again when your poses reach
  them after the gap. A recording can run at the same time as either one.

See [dev/architecture.md](dev/architecture.md#loopback-record-and-replay) for the parts of the pipeline each one tests.

### Commands that need a co-op save

`coop no` (the probe) and `coop recruiter` (the cut recruiter) are research previews of the cut Night Operation mode,
not a playable mode. They run only on a [co-op save](players/playing-with-a-friend.md#co-op-saves) and need preparation first: read
[online/modes/nightop-previews.md](online/modes/nightop-previews.md) before you use them. The recruiter also appears by himself
at each Xion load, on any save. Otherwise they stop with:

```
STOP: coop no runs only on a co-op save (INSTALL.md: Co-op saves); now <the slot line>
```

(`now no slot status` without the native part.)

`coop nightop`, Night Operation's run and its shop, and `coop challenge`, the challenges, run only on a co-op save too,
with the same `STOP:` line under their own names, except `coop nightop stop` and `coop challenge stop`, which work on
any save. See [online/modes/nightop.md](online/modes/nightop.md#the-solo-run-coop-nightop) and
[Challenges](online/modes/challenges.md).

- With no Steam session, `coop nightop start` starts a solo run. A level may follow `start`: `easy`, `normal` (the
  same as none), `hard` or `nightmare`. It sets the number of monsters in each wave (15 to 40 in all), the time limit
  (9:00 to 7:00) and the shop points (50 % to 200 %). See [Levels](online/modes/nightop.md#levels).
- In a session, only the host starts a run, at his level, and it is for both players. The guest's game checks her
  side and joins without a question, or the host gets a notice with the reason she cannot. On the guest's game the
  command answers `STOP: the host starts a co-op run`. See [online/modes/nightop.md](online/modes/nightop.md#the-co-op-run).
- In a co-op run, a dead EVE whose player has `revive=on` is down for 30 s. Her partner revives her by holding the
  interact key (F, or the pad's right trigger) for 3 s next to her, or she types `coop nightop revive` (3 times a run
  at easy, 2 at normal, 1 at hard, none at nightmare). See [Down and revive](online/modes/nightop.md#down-and-revive).
- `coop nightop shop` opens the game's own shop screen with the seven items, your points as Beta Seeds while it is
  open (see [online/modes/nightop-shop.md](online/modes/nightop-shop.md#status-lines)). `coop nightop buy` lists the points your runs
  gave and the seven items, and `coop nightop buy <n> [count]` buys 1 to 10 of item n into the co-op save. Items 5 and
  6, the cut Burst and Beta Stimpacks, need table rows the native part adds with the Lion's (see
  [Cut boss](fight/bosses.md#cut-boss-coop-lion)), and item 7, the cut [Shock Bolt](online/modes/nightop-shop.md#cut-ammo-shock-bolt) ammo, rows of its own: a buy
  of one asks for them first, and the screen asks for both. Your points are in `coop-night-<steamid>-<index>.txt` in the
  mod folder, one file per Steam ID and co-op slot. See [online/modes/nightop-shop.md](online/modes/nightop-shop.md).
- `coop challenge range` (or `coop challenge 5`) starts the Shooting Range: three rounds of 3, 4 and 5 of the game's
  target dummies, all around EVE, in 2:00. It is made for the drone's ranged mode, which needs the gun the story
  unlocks; the sword reaches the dummies too. Alone it needs no Steam session; in a session the host starts it for
  both players, as a co-op Night Operation run. Its score also shows on the cut test widget `WB_ShootingTrainingTest`.
  See [online/modes/challenges.md](online/modes/challenges.md#shooting-range).
- On a co-op save, Roxanne in Xion offers Night Operation (Easy, Normal, Hard) and its supplies in her dialogue. See
  [online/modes/nightop-shop.md](online/modes/nightop-shop.md#night-operation-at-roxannes).

The ghost, the link and every other command except `coop fight` (see [Shared enemies](fight/enemies.md#shared-enemies-experimental)), `coop race start`, `coop race look on`,
`coop race probe doro` and `coop race drive probe` (see [Doro races](online/modes/race.md)), `coop leviathan show`,
`coop leviathan cam` when it turns the camera on (and the same two in the six other
[viewer commands](fight/bosses.md#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril)), `coop lion`, `coop lion intro`,
`coop lion control`, `coop gardener fight` with no word, `intro`, `half` or `skulling`, `coop tendril fight` with no
word, `coop chainspin`, a scene of `coop scene`, `coop fly on`, `coop slowmo on`, `coop glide on`, a row of
`coop devmenu` and `coop gift` (see [cutmenus/menus.md](cutmenus/menus.md#cut-mailbox-coop-gift)) run on any save.
`coop fight pilot` runs on any save too, since same place only moves enemies while shared enemies run.

### `coop off`

`coop off` stops the following until the game restarts, even across a Lua reload:

- the ghost, EVE's capture, the loopback, a recording (which is written) and a replay;
- engine reads and the Steam link;
- the screen notices, the co-op menu, the chat box, the feed and the partner HUD (the game gets its keys back), and the
  chat history (cleared);
- a [score attack](online/modes/scoreattack.md#what-stops-a-round) round (your run ends as aborted and your game
  sends nothing more; the other players count you as a player who left) and a death screen its respawn hid (shown
  again);
- a [fishing tournament](online/modes/fishing.md#what-stops-a-tournament) (your game sends nothing more and stops
  its book reads; the host counts you as a player who left);
- a Night Operation run or a challenge (it ends as aborted, and so does the partner's co-op run; your shop points stay
  as they are), the Night Operation poller, the Night Operation shop screen (closed, its seeds back in your wallet) and
  Roxanne's Night Operation choices (her own two back, and a run booked at her dropped);
- the recruiter (despawned in Xion if he was brought there, and not brought back again);
- the SBO lobby's table rows (back to the game's values);
- the shared quests;
- the shared world (its hooks are taken out of the game's slots);
- story together (its hooks are taken out of the game's slots; a scene of hers still paused is given back);
- the photo pause (released; the native tick keeps running for this alone);
- a Doro race (left as a DNF, or cancelled before GO, with EVE's movement values put back), the drive probe, a race
  track being recorded (dropped, nothing written) and the Doro look (EVE drawn again);
- the cut model display and its free camera (`coop leviathan` and the other viewer commands; the view goes back as it
  was);
- what `coop lion` is doing (a wait for its rows, its search, its entrance copy, its log lines; a living Lion stays),
  and the same for `coop gardener fight` and `coop tendril fight` (a living Gardener or Tendril stays);
- the `coop wear` look (your EVE's own hair and suit come back) and a `coop lines` scene;
- the game's developer flight and slow motion (`coop fly` and `coop slowmo`: the game's values come back), the cut glide
  (`coop glide`: EVE's glide flag is cleared) and a `coop emote` clip (it blends out);
- the [bike](vehicles/bike.md) (EVE gets off: the game's actions, her movement values and her mesh come back; the native part
  frees the bike's loaded files);
- the day and night cycle (Stellar Blade's own light, sky domes and SkyCreator time come back);
- the game's developer panels (`coop devinfo`: closed);
- a `coop shortcut` list under way and the gift toast (taken off the screen).

When a `coop devmenu` row ran, `coop off` runs its `clear` and `lockswitch` rows once more, but that `clear` reaches
only the enemies near EVE at that moment, and both are skipped while a respawn or a warp is under way (see
[Developer menu](cutmenus/menus.md#developer-menu-coop-devmenu-and-coop-devinfo)). A `coop gift send` caught after
the items left your inventory and before the gift reached your mailbox file stops there, and those items are lost. Gift
lines from your friend that arrive after `coop off` are dropped without an answer. Afterwards only `coop status` and
`coop report` answer. Every other command answers `STOP: coop off is active until the game restarts`, and so do the
menu, host, leave and bike keys. The race key does nothing.

## Status lines

### The status key (F6)

F6 gives one line, in the log (`OK: ...`) and on screen as a notice:

- `Co-op: not in a session.`
- `Co-op: hosting, no friend yet.`
- `Co-op: <name> is connecting.`
- `Co-op: hosting <name>.` or `Co-op: in <name>'s game.` (`Paused by <name>.` while their photo mode pauses your game;
  a lost friend adds `Connection lost.`). In a session of more than 2 players, `<name>` is the host on a guest and the
  pair on the host (else the first guest linked), then ` +<n>` for the other members linked. `Paused by <name>.` names
  the host alone: only the host's photo mode pauses a guest past 2 players.
- `Co-op: invite held until your save has loaded.`
- `Co-op: rejoining your friend's game (try <n>/3).`
- `Co-op: waiting for Steam.`
- `Co-op: the Steam link stopped; coop status says why.`

### `coop status`

`coop status` prints the full state on one log line, its parts separated by ` | `. In that line each SteamID shows as
`***` and its last 4 digits, the join code and the lobby id as the code's first 3 characters and `****`, as in every
line the mod writes to its logs. `coop-status.txt` in the mod folder holds the same state with them whole.

- Steam: `mod=<version> proto=25 steam=<waiting|ready>`, then the Steam ID, app id, game build, overlay, relay
  availability and callback counts, your Steam name on a `me=` line, then `blocked=<n>`: the players on your
  [block list](players/playing-with-a-friend.md#block-list). A `block=<SteamID> <name>` line follows for each player you
  blocked in this game run.
- Link: `link=<none|host|guest> lobby=<id>`, with `pending=1` while a lobby call runs, `held=<lobby>` for an invite held
  and `rejoin=<n>/3` while rejoining. While you host, a `code=<join code|none> refused=<n>` line follows: the join code
  (`none` outside an Invitation session) and the number of players refused for the rest of this lobby, blocked players
  who came in included; then a `pending=<SteamID> <name>` line for each player who waits for your answer (not your Steam
  friend, or any player with `friends_ask=on`), in the order the native part asks about them. As a joiner who waits for
  the host's answer, a `wait=<seconds left> <host's name>` line. While a session list lasts, a `list=` line and a
  `session=` line per row ([The session list](online/steam-link-internals.md#the-session-list)). In an online session,
  `host=<host's SteamID> pair=<pair's SteamID or 0, yours when you are the pair> max=<max_players, 0 before a guest
  heard it>` and `players=<the players in the session as the host counts them, you and the host included, 0 before a
  guest heard it>` ([Sessions of more than 2 players](online/steam-link-internals.md#sessions-of-more-than-2-players)).
  Then a `peer=...` line per lobby member (handshake, lost flag, RTT), a `friend=<linked 0|1> <lost 0|1> <name>` line,
  after a [coop mark](#coop-mark) a `mark=<n> ours: <text>` or `mark=<n> from <name>: <text>` line (no `: <text>` for a
  mark with no text), a `mate=<13 numbers>` line with your friend's HP, shield, Beta, Burst and Tachy for the partner
  card, then her zone type (while their last reading is under 3 s old; your own during `coop loopback`), a
  `vit=<SteamID> <13 numbers>` line for each member linked whose last reading is under 3 s old (neither line in a match
  lobby), a `life=<state> <hp>` line
  with your own EVE's life state (1 or 6 alive, 3 to 5 dying or dead) and HP for the revive, a `night=<line>` line with
  your friend's last Night Operation line while a session holds, and the last 8 notices as `notice=<n> <text>`. While
  you host, `camps?=<n>` is your game's number for the oldest request for the camps nearest you still waiting for an
  answer, else for the last one (your answer to that number goes to that guest alone, with her own id); as the guest,
  `camps=<id> <answer>` is the host's last answer ([Following the
  host](players/playing-with-a-friend.md#following-the-host)).
  While linked, `spot?=<n>` is your game's number for the oldest request for your last ground point still waiting for
  an answer, else for the last one taken. `spot=<id> <answer>` is the answer to your own last request
  ([The spot lines](online/steam-link-internals.md#the-spot-lines)).
- Pose path: `engine=on` (then `loopback=on <delay> <jitter> <loss>` or `loopback=waiting` until EVE's capture comes,
  `record=on`, `replay=on`, `remote=<generation> <count> <loopback|replay|peer>`, then in a match lobby or an online
  session of more than 2 players `remote<k>=<generation> <count>` for each other member's ghost slot k from 1 to 6), or
  `engine=off reason=<why>`; then `warp=<idle|busy> me=<n>` (a respawn or a warp under way, and your EVE's id, for the
  revive) with `zonetype=<0-6> area=<zone|none> rest=<n>:<zone>:<type> starts=<n>` (your zone's type, 2 to 6 a
  [solo area](players/playing-with-a-friend.md#solo-areas); the zone a rest resets, `none` while the world and the
  game's logic name different zones; your own zone resets with the zone and type of the last one; every start of
  one, see [Rests between members](online/group-internals.md#rests-between-members)),
  `travel=<state> travel_calls=<n>` (the last travel's state: `idle`, `pending`, `warping`, `arrived` or
  `refused:<why>`, and the travel requests handled so far), `anim=<state> anim_id=<n>` (the last `coop emote` clip or
  bike pose the native part took and what became of it: `idle`, `playing`, `ended`, `ended:weight`, `stopped`,
  `refused:<why>` or `fault`, see [Emotes](eve/eve.md#emotes-coop-emote)), `bike=<off|loading|ready|failed:<why>|fault>
  bike_gate=<on|off|refused:<why>>` and `bike_life=<n>` (the
  [bike](vehicles/bike-internals.md#status-words-and-the-latch)'s preload, the game's actions while EVE rides, her life
  state), `keep=<asked> <settled> <in>` or `keep=fault` (the counts of the
  [keep](dev/architecture.md#files-shared-by-lua-and-the-native-part)'s paths: asked by Lua, settled, found in
  memory), `theater=<none|sequence|->` or `theater=fault` (SB's theater, read every 100 ms: `none`, the sequence it
  plays, or `-` while its first take loads or its name is not read), `items=<ask> <count>` or `items=<ask> none <why>`
  (the answer to [`coop
  gift`](cutmenus/menus.md#cut-mailbox-coop-gift)'s last inventory read, by its number; why is `unpinned`, `noeve`,
  `nomanager`, `nobucket` or `unread`), `fish=<ask> <ID>:<count>,...`, `fish=<ask> -` or `fish=<ask> none <why>` (the
  answer to the [fishing tournament](online/modes/fishing.md#the-book-read)'s last read of SB's fishing log book, by
  its number; why is `unpinned`, `noeve`, `nobook` or `unread`), and `nightop=on` or `nightop=rule` while the probe's
  poller runs.
- Activated camps: `activated=<n>:<camp>,<camp>,...` lists the camps of the game's camp table (simple and full camps,
  phone booths, tetrapods) that the game's own camp list would show for this save, read every 2 s while you play,
  followed by `rested=<camp>`, the camp where EVE respawns (that of her last rest or fast-travel arrival), when the
  mod knows it. `activated=none:<why>` means there is no read now: `flow` or `phase` at the title or during a load,
  `fault` once a fault stopped the read until the game restarts, and another word for a part of the game the mod found
  missing. After a fault, `coop-link.log` has `camps read off: fault 0x... at StellarCoop.dll+0x... reading 0x...;
  coop travel probe and coop mxiii leave refused until the game restarts`, once.
  [`coop travel probe`](players/playing-with-a-friend.md#following-the-host) and `coop mxiii leave` take only camps from this list.
- Save slot: `slot=<coop|main|none|unknown> index=<n|?> marker=<n|none|bad|?> saves=<coop|main|off|?>` (see
  [players/saves.md](players/saves.md#co-op-saves)). `saves=` names the save files the game uses: `main` for your own,
  `coop` for the co-op copies (`StellarBladeCoop00.sav` to `04`), `off` when the mod cannot read the file name (another
  game build, or a check failed), and `?` before the first read or once the name moved in the game's memory (no switch
  until the game restarts). `coop-link.log` logs each change as `save name: saves=<value>`, with the reason for `off`
  and `?`. After `coop off` it keeps the last value read, since the game keeps that file name until it exits.
- Co-op save copies: `convert=<idle|busy <done>/<jobs>|done|error:<why>>`, the last copy pass (`idle` before any).
- Shared enemies: `fight=on mode=<on|probe|record|replay> ...` with its counts, `fight=waiting mode=<mode> why=<what it
  waits for>`, `fight=stopped why=<why>` or `fight=off`, with `her=<state>` while a friend is linked (see [Shared
  enemies](fight/enemies.md#shared-enemies-experimental)). While it runs, the line ends with `boss=<0|1>` (a boss fight on your side),
  `battle=<n>` (enemies in battle within 30 m of your EVE) and `epoch=<zone>/<n>/<resets>` (same spawns' zone and epoch,
  and how often your own zone reset this run).
- Same place: `pilot=on piloted=<n>`, `pilot=off why=<why>`, `pilot=stopped` or `pilot=refused why=<why>` (see
  [Same place](fight/enemies.md#same-place-experimental)).
- Shared quests: `quests=off`, `quests=waiting mode=<mode> why=<friend|save|game>`, `quests=on mode=<mode>
  role=<role> partner=<on|off>` (on a host with several guests, then `with=<SteamID>` of the first guest whose side is
  on) or `quests=stopped` (see [Shared quests](players/playing-with-a-friend.md#shared-quests-experimental)), then the last 8
  quest notices as `quest_note=<n> <kind> <number> <name> <zone or ->`, with the guest's SteamID after a host's
  `ahead` note, then the last `coop quests status` answer as `quests_status=<n> <line>` lines.
- Shared world: `world=off`, `world=waiting why=<friend|match|save|partner>`, `world=on`, then its counters, or
  `world=stopped`, `world=off why=build` or `world=off why=coop_off` (see [Shared world](world/objects.md#status-line)
  and the counters in [Shared world: how it works](world/objects-internals.md#status-line)).
- Story together: `story=off`, `story=waiting why=<friend|match|save|partner>`, `story=on`, then `scene=` and its
  counters, or `story=stopped`, `story=off why=build` or `story=off why=coop_off` (see
  [Story together](story/together.md#status-line) and the counters in
  [Story together: how it works](story/together-internals.md#status-line)). Its changes are not logged as `link:` lines:
  its counters move with each position of a shared scene.
- Day and night: `sky=<state> h=<hour> el=<sun's elevation> ...`, the [day and night cycle](world/daynight-internals.md#the-request-and-the-status-line)'s
  state, hour, sun and moon, light factors and env volumes. Its changes are not logged as `link:` lines: its hour moves
  each second.
- Photo mode: `photo=<0|1|s|c> peer_photo=<0|1|s|c> frozen=<0|1> sync=<both|notice|off>`: yours and your friend's (`s`
  for selfie mode, `c` on the host while a cutscene plays: the [cutscene wait](players/playing-with-a-friend.md#cutscene-wait)), whether your game holds
  the photo pause (`coop freeze` holds it too), and the `photo_sync` your friend gets (`notice` when your game cannot
  pause).
- Last event: `last=<the last coop-link.log event>`.
- Ghost: `ghost=on parts=<n> leaders=<n> basesuit=<0|1> left_out=<n> table=<generation> source=<source>
  collide=<on|off|failed>`, `ghost=waiting`, `ghost=hidden map` or `ghost=off`, plus `stray_parts=<n>` if ghost parts
  that are not this load's ghost stand in the world. Once the [solid partner](online/partner.md#solid-partner-experimental)'s capsule
  exists, `collide=` adds `solid=<0|1>` and `changes=`, the times it turned solid and the times each rule let your EVE
  through (`a` hidden or off, `b` overlap, `c` height, `d` movement mode, `e` 2 s of contact, `g` your friend down).

Each changed status line, except the per-peer ones, the `fight=` line, the `mate=`, `vit=` and `life=` lines, the
`night=` line (Night Operation's run logs each one as an `[NR]` line), the `story=` line and the `sky=` line, also goes
to `UE4SS.log` as `[StellarCoop] link: ...`.
Each load logs the save slot as `link: slot=...`.

## Sections that moved

Each section that left this page is listed under its old name, with its new place.

| Section | Now in |
| --- | --- |
| Co-op menu | [players/interface.md](players/interface.md#co-op-menu) |
| Co-op line | [players/interface.md](players/interface.md#co-op-line) |
| Controller | [players/interface.md](players/interface.md#controller) |
| Mouse | [players/interface.md](players/interface.md#mouse) |
| Options | [players/interface.md](players/interface.md#options) |
| Focus watchdog | [players/interface.md](players/interface.md#focus-watchdog) |
| Session chat | [players/interface.md](players/interface.md#session-chat) |
| Partner HUD | [players/interface.md](players/interface.md#partner-hud) |
| Status strip above the card | [players/interface.md](players/interface.md#status-strip-above-the-card) |
| Playing with a friend | [players/playing-with-a-friend.md](players/playing-with-a-friend.md) |
| Your world and your friend's | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#your-world-and-your-friends) |
| Join codes | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#join-codes) |
| Following the host | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#following-the-host) |
| A player down | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#a-player-down) |
| Revive by your friend (experimental) | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#revive-by-your-friend-experimental) |
| Camp rests in a shared area | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#camp-rests-in-a-shared-area) |
| Known limits | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#known-limits) |
| Guide | [players/interface.md](players/interface.md#guide) |
| Co-op saves | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#co-op-saves) |
| Synced photo mode | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#synced-photo-mode) |
| Photo mode pause (experimental) | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#photo-mode-pause-experimental) |
| Cutscene wait | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#cutscene-wait) |
| Doro races | [online/modes/race.md](online/modes/race.md) |
| Recording a track | [online/modes/race.md](online/modes/race.md#recording-a-track) |
| Starting a race | [online/modes/race.md](online/modes/race.md#starting-a-race) |
| Slots and countdown | [online/modes/race.md](online/modes/race.md#slots-and-countdown) |
| Driving | [online/modes/race.md](online/modes/race.md#driving) |
| Rules | [online/modes/race.md](online/modes/race.md#rules) |
| Results | [online/modes/race.md](online/modes/race.md#results) |
| The Doro look | [online/modes/race.md](online/modes/race.md#the-doro-look) |
| Limits | [online/modes/race.md](online/modes/race.md#limits) |
| Track files | [online/modes/race.md](online/modes/race.md#track-files) |
| Teleport screen | [players/interface.md](players/interface.md#teleport-screen) |
| Night Operation previews | [this page: Commands that need a co-op save](#commands-that-need-a-co-op-save) |
| Night Operation's shop screen and Roxanne's choices | [online/modes/nightop-shop.md: Status lines](online/modes/nightop-shop.md#status-lines) |
| Cut enemy preview: `coop leviathan`, `coop gardener` and `coop tendril` | [fight/bosses.md](fight/bosses.md#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril) |
| Other cut models: `coop mann`, `coop nier`, `coop orcal` and `coop enya` | [fight/bosses.md](fight/bosses.md#other-cut-models-coop-mann-coop-nier-coop-orcal-and-coop-enya) |
| Free camera | [fight/bosses.md](fight/bosses.md#free-camera) |
| Cut boss: `coop lion` | [fight/bosses.md](fight/bosses.md#cut-boss-coop-lion) |
| Cut enemy: `coop gardener fight` | [fight/bosses.md](fight/bosses.md#cut-enemy-coop-gardener-fight) |
| Cut enemy: `coop tendril fight` | [fight/bosses.md](fight/bosses.md#cut-enemy-coop-tendril-fight) |
| Cut Tachy skill: `coop chainspin` | [eve/eve.md](eve/eve.md#cut-tachy-skill-coop-chainspin) |
| Cut ammo: Shock Bolt | [online/modes/nightop-shop.md](online/modes/nightop-shop.md#cut-ammo-shock-bolt) |
| Cut dungeon: `coop mxiii` (experimental) | [world/matrix13.md](world/matrix13.md) |
| Lily's signal (experimental) | [lily-signal.md: Status lines](world/lily-signal.md#status-lines) |
| Cut hairs and suits: `coop wear` | [eve/eve.md](eve/eve.md#cut-hairs-and-suits-coop-wear) |
| Cut scenes: `coop scene` | [story/scenes.md](story/scenes.md#cut-scenes-coop-scene) |
| Cut scene lines: `coop lines` | [story/scenes.md](story/scenes.md#cut-scene-lines-coop-lines) |
| Emotes: `coop emote` | [eve/eve.md](eve/eve.md#emotes-coop-emote) |
| Debug flight and slow motion: `coop fly` and `coop slowmo` | [eve/eve.md](eve/eve.md#debug-flight-and-slow-motion-coop-fly-and-coop-slowmo) |
| Cut glide: `coop glide` | [eve/eve.md](eve/eve.md#cut-glide-coop-glide) |
| Cut Load Shortcut saves: `coop shortcut` | [cutmenus/menus.md](cutmenus/menus.md#cut-load-shortcut-saves-coop-shortcut) |
| Loading one: `coop shortcut load` | [cutmenus/menus.md](cutmenus/menus.md#loading-one-coop-shortcut-load) |
| Developer menu: `coop devmenu` and `coop devinfo` | [cutmenus/menus.md](cutmenus/menus.md#developer-menu-coop-devmenu-and-coop-devinfo) |
| Cut mailbox: `coop gift` | [cutmenus/menus.md](cutmenus/menus.md#cut-mailbox-coop-gift) |
| Shared enemies (experimental) | [fight/enemies.md](fight/enemies.md#shared-enemies-experimental) |
| Same place (experimental) | [fight/enemies.md](fight/enemies.md#same-place-experimental) |
| Same spawns (experimental) | [fight/enemies.md](fight/enemies.md#same-spawns-experimental) |
| Spawn filter (experimental) | [fight/enemies.md](fight/enemies.md#spawn-filter-experimental) |
| Extra enemies (experimental) | [fight/enemies.md](fight/enemies.md#extra-enemies-experimental) |
| Shared bosses (experimental) | [fight/enemies.md](fight/enemies.md#shared-bosses-experimental) |
| Shared quests (experimental) | [players/playing-with-a-friend.md](players/playing-with-a-friend.md#shared-quests-experimental) |
| coop-settings.txt | [players/settings.md](players/settings.md#coop-settingstxt) |
| Looks | [online/partner.md](online/partner.md#looks) |
| Mods and CNS outfits | [online/partner.md](online/partner.md#mods-and-cns-outfits) |
| Mods you both have | [online/partner.md](online/partner.md#mods-you-both-have) |
| When a mod asset fails | [online/partner.md](online/partner.md#when-a-mod-asset-fails) |
| Solid partner (experimental) | [online/partner.md](online/partner.md#solid-partner-experimental) |
| Notices | [players/interface.md](players/interface.md#notices) |
| Files in the mod folder | [players/settings.md](players/settings.md#files-in-the-mod-folder) |
