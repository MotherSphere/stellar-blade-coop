# Documentation

To install the mod, start with [Install](../INSTALL.md); to play, with
[Playing with a friend](players/playing-with-a-friend.md). The pages under [Building and internals](#building-and-internals)
describe the code, for anyone who builds the mod or changes it. Stellar Blade Online was first called StellarCoop, and
its folder, its DLL, its `[StellarCoop]` log tags and its release zip keep that name; its console commands still
start with `coop`.

## Install and play

| Page | What it covers |
| --- | --- |
| [Install](../INSTALL.md) | Install, update and uninstall on Windows, Linux and the Steam Deck; saves and Steam Cloud; which logs to send |
| [Features and test status](features.md) | The features with their test status, the dated two-PC tests and which versions link together |
| [Playing with a friend](players/playing-with-a-friend.md) | Hosting and joining, join codes, following the host, the revive, co-op saves, synced photo mode, shared quests |
| [Interface](players/interface.md) | The co-op menu, the session chat, the partner HUD, the guide, the teleport screen, notices |
| [Settings](players/settings.md) | `coop-settings.txt` as the mod writes it, the files in the mod folder |
| [Keys and commands](usage.md) | Every key and `coop` console command, the F6 and `coop status` lines, and the new place of each section that moved |
| [Saves](players/saves.md) | What the mod reads and writes, backups, Steam Cloud, the co-op saves, recovery |
| [Troubleshooting](players/troubleshooting.md) | Where to look, problems grouped by topic, the 60 s link lines, which logs to send |

## Online

| Page | What it covers |
| --- | --- |
| [SBO lobby and matches](online/lobby.md) | The recruiter's Join, the lobby menu, Search, private matches, the countdown, leaving, the hall lobbies, the PvP test, the link protocol |
| [Ghost](online/partner.md) | The ghost's looks, .pak mods and CNS outfits, the solid partner |
| [Night Operation](online/modes/nightop.md) | The cut mode, the plan, the solo run, the co-op run, credits |
| [Reward shop](online/modes/nightop-shop.md) | The points, the seven items, the shop screen, Roxanne's choices, the cut Shock Bolt |
| [Challenges](online/modes/challenges.md) | `coop challenge`, Target Practice, the Shooting Range alone and for two, score, best runs |
| [Score attack](online/modes/scoreattack.md) | The SBO lobby's match mode where every player plays the same challenge: starting a round, the host's pick, the ranking and its checks, the screens, best match runs, `coop scoreattack`, the score line |
| [Fishing tournament](online/modes/fishing.md) | The online session's mode where every player fishes for the same minutes: `coop fish start`, the points, the host's checks and their limits, the corner board and the result panel, best tournaments, the book read, the mode line |
| [Photo hunt](online/modes/photohunt.md) | The online session's mode where every player photographs three of SB's photo targets: `coop photohunt start`, which maps have targets, SB's photo check, the host's checks and their limits, the card and the result panel, best photo hunts, the mode line |
| [Night Operation previews](online/modes/nightop-previews.md) | The probe (`coop no`), the recruiter (`coop recruiter`), how the original matchmaking is blocked |
| [Doro races](online/modes/race.md) | Recording a track, starting a race, driving, rules, results, the Doro look, races in a match of the SBO lobby (the Track row, the tracks a room offers, the ranking and its checks, best times, `coop race match`), track files |

## Fight

| Page | What it covers |
| --- | --- |
| [Shared enemies](fight/enemies.md) | Shared enemies, same place, same spawns, the spawn filter, extra enemies, shared bosses |
| [Cut enemies](fight/bosses.md) | The cut model viewer and its free camera, the Lion as a boss, the Gardener and Tendril fights |
| [Gun mode](fight/gunmode.md) | The NIKKE rifle outside its missions: parked while it is rebuilt, the rifle layer and its pak, the tables it changes, the keys, firing mode, the rounds, the frame cost, `coop gun`, the settings, credits |

## World

| Page | What it covers |
| --- | --- |
| [Shared world](world/objects.md) | Doors, levers, lifts and shortcuts one player works changing in the other's game; what stays each player's own; the setting and `coop world` |
| [Matrix XIII](world/matrix13.md) | The cut area, `coop mxiii` and its test pak |
| [Lily's signal](world/lily-signal.md) | The mod's two quests that lead through Matrix XIII, their talks, lines and status lines |
| [Team shop](world/teamshop.md) | `coop teamshop`: outfits made by the SBO team for gold in the game's own shop screen on a co-op save; when it refuses |
| [SBO Xion](world/maps/sboxion.md) | An empty Xion in a world of SBO's own (experimental): `coop xion`, its test pak, its rows, the warp, the light, the log lines of its first test |

## Story

| Page | What it covers |
| --- | --- |
| [Story together](story/together.md) | The host's cutscenes and talks played in the guest's game with his choices, QTE results and skips; story trips; quest steps the guest makes first; the setting and `coop scenes` |
| [Cut scenes](story/scenes.md) | `coop scene`, `coop lines` |

## Vehicles

| Page | What it covers |
| --- | --- |
| [The bike](vehicles/bike.md) | Getting on and off, the refusals, riding, `coop bike`, the settings, the ghosts, credits to Eve On Wheels and Eve Hoverbike |

## EVE

| Page | What it covers |
| --- | --- |
| [EVE's cut moves](eve/eve.md) | `coop chainspin`, `coop wear`, `coop emote`, `coop fly`, `coop slowmo`, `coop glide` |

## Cut menus

| Page | What it covers |
| --- | --- |
| [Cut menus and the mailbox](cutmenus/menus.md) | `coop shortcut`, `coop devmenu` and `coop devinfo`, `coop gift` |

## Stellar Closet

| Page | What it covers |
| --- | --- |
| [Stellar Closet](closet/closet.md) | EVE's outfits as pieces in slots, `coop closet` |
| [Importing CNS-format packs](closet/cns-import.md) | How `*.dekcns.json` packs map to items, the clean-room rules |

## Building and internals

The game addresses in the internals pages are build 26123051's, the build the code pins. They were read on build
24463856 and matched to their build 26123051 values by comparing the two executables; none of the old addresses is
left. The pages still name build 24463856 where a fact was read on that build, such as the table dumps.

| Page | What it covers |
| --- | --- |
| [Building](dev/building.md) | Toolchain, `tools/install.py`, `tools/wine_smoke.py`, the reproducible build, releases, repository layout |
| [Structure](dev/structure.md) | How the code is organised into modules and the rules that keep them apart |
| [Migration](dev/migration.md) | Where each file of the two November 2026 restructures went, for forks |
| [Porting](dev/porting.md) | [The port to a new game build, step by step](dev/porting.md#the-port-step-by-step), [what the signatures cannot find](dev/porting.md#what-the-signatures-cannot-find), the game addresses the native code uses, `tools/port/addresses.py`, `tools/port/make_signatures.py`, the byte signatures in `tools/port/signatures.json` and `tools/port/find.py` |
| [SBO UE4SS](dev/ue4ss.md) | SBO's UE4SS package: the official UE4SS v4.0.0 files, SBO's settings, the files of each Stellar Blade build, [adding a build](dev/ue4ss.md#adding-a-build), licenses |
| [Tests](dev/tests.md) | The Lua, C++ and Python tests and what each one checks |
| [How it works](#how-stellar-blade-online-works) | Index of the internals pages, and where each section of the old single page went |
| [Architecture](dev/architecture.md) | The Lua and native parts, the Lua scripts, the files they share, the modules and their isolation, the co-op UI's input, loopback, record and replay |
| [The Steam link](online/steam-link-internals.md) | Lobby and invites, the handshake, channels 0 and 1, protocol versions, link health |
| [The ghost pipeline](online/partner-internals.md) | The ghost in seven steps, looks, the CNS guard and crash sentinel, the solid partner |
| [Group play: how it works](online/group-internals.md) | Shared quests, following the host, the teleport screen, the revive, camp rests, the cutscene wait |
| [Doro races: how they work](online/modes/race-internals.md) | The display Doro, the Doro look, the ghost's Doro mode, driving, the native hold, race lines, races in a match and their dr lines |
| [Night Operation's shop: how it works](online/modes/nightop-shop-internals.md) | The shop screen and its wallet, Roxanne's choices, the cut stimpacks, the cut Shock Bolt |
| [Shared enemies: how they work](fight/enemies-internals.md) | Same-place enemies, same spawns and the spawn filter, extra enemies, shared bosses |
| [Cut enemies: how they are added](fight/bosses-internals.md) | The cut Lion with the row batches, the cut Gardener, the cut Tendril |
| [Shared world: how it works](world/objects-internals.md) | The four roots and their hooks, the generated filter, the SBW lines, how her changes are made, the status line, the addresses |
| [Day and night: how it works](world/daynight-internals.md) | The shared UTC clock, the sun and moon, the dawn and dusk ramps, the map table, the rules, the env fields the native part writes, the request and status line, the cost |
| [Matrix XIII: how it works](world/matrix13-internals.md) | The cut area's rows, event spawns, arrival, camps, save, title and world rows |
| [Lily's signal: how it works](world/lily-signal-internals.md) | The rows, quests and talks of Lily's signal |
| [Story together: how it works](story/together-internals.md) | The host's theater reads and hooks, the scene and trip tables, the SBS lines, the guest's gate, leash and results, the guest's quest steps, the status line, the addresses |
| [The bike: how it works](vehicles/bike-internals.md) | The preload, the part on EVE, mount and dismount, the gate, the riding pose, the riding model, the lean, the ghosts |
| [EVE's cut moves: how they work](eve/eve-internals.md) | The cut ChainSpin, developer flight and slow motion, the cut glide, emotes |
| [Cut menus and the mailbox: how they work](cutmenus/menus-internals.md) | The cut Load Shortcut menu, the developer menu and panels, the cut mailbox |
| [Achievements and safety design](dev/safety.md) | Which kills and achievements count for each player, the safety design |
| [Story dump](dev/story-dump.md) | `coop story`, `tools/story_lines.py` and `tools/save_read.py`: the story state of a save or of the running game, one line per value |
| [Bike paint](dev/modding/bike-paint.md) | Adding an outfit's paint to `Paint.BY_MESH`: the key, the bike's slots and parameters, the check |
| [Map pipeline](dev/modding/maps.md) | What a map needs in the game's tables, the steps with and without the editor, which steps the repository holds |
| [Team shop items](dev/modding/items.md) | Adding an item to the team shop: the data file, the ID ranges, the fields an item may set, the commands, what the checks refuse, the limits |
| [Modules](dev/modding/modules.md) | A module's files, a skeleton to copy, reading another module, registering one |

## How Stellar Blade Online works

Each internals topic has its own page beside the page it explains: how the code does what the player pages describe,
for anyone who reads or changes the code. The commands are in [usage.md](usage.md). The code layout is in
[dev/building.md](dev/building.md#repository-layout).

Code comments still cite sections of this page by name, for example `native/src/world/maps/matrix13/mxiii_rows.h` and
`tools/mxiii_rows.py` ("Matrix XIII's world rows") and `mod/StellarCoop/Scripts/cutmenus/mailbox.lua` ("Achievements"),
so [Where each section went](#where-each-section-went) gives the new place of every section that used to be here.
`core/enemy.lua`, its copy `fight/bosses/enemy.lua` and `online/modes/nightop/run.lua` cite this page for how a spawned
body reads its state and how the game reuses Lion bodies, which is in
[fight/bosses-internals.md: The spawn](fight/bosses-internals.md#the-spawn).

### The internals pages

| Page | What it covers |
| --- | --- |
| [dev/architecture.md](dev/architecture.md) | The Lua and native parts, the Lua scripts, the files they share, the modules and their isolation, the co-op UI's input, loopback, record and replay |
| [online/steam-link-internals.md](online/steam-link-internals.md) | Lobby and invites, players who are not Steam friends, the handshake, channels 0 and 1, protocol versions, link health in the log |
| [online/partner-internals.md](online/partner-internals.md) | The ghost pipeline in seven steps, looks, the CNS guard and crash sentinel, the solid partner |
| [fight/enemies-internals.md](fight/enemies-internals.md) | Same-place enemies, same spawns and the spawn filter, extra enemies, shared bosses |
| [online/group-internals.md](online/group-internals.md) | Shared quests, following the host, the teleport screen's extra tabs, a player down and the revive, camp rests, the cutscene wait |
| [world/objects-internals.md](world/objects-internals.md) | The shared world's roots and hooks, its filter, its lines, how the partner's changes are made, its status line and addresses |
| [story/together-internals.md](story/together-internals.md) | Story together's theater reads and hooks, its tables, its lines, the guest's gate, leash and results, the guest's quest steps, its status line and addresses |
| [online/modes/race-internals.md](online/modes/race-internals.md) | The display Doro, the Doro look, the ghost's Doro mode, driving, the native hold, race lines, races in a match and their dr lines |
| [world/daynight-internals.md](world/daynight-internals.md) | The day and night cycle: the shared clock, the sun and moon, the map table, the rules, the env fields written, the request and status line, the cost |
| [vehicles/bike-internals.md](vehicles/bike-internals.md) | The bike: the preload, the part on EVE, mount and dismount, the gate, the riding pose, the riding model, the lean |
| [fight/bosses-internals.md](fight/bosses-internals.md) | The cut Lion with the row batches, the cut Gardener, the cut Tendril |
| [eve/eve-internals.md](eve/eve-internals.md) | The cut ChainSpin, developer flight and slow motion, the cut glide, emotes |
| [cutmenus/menus-internals.md](cutmenus/menus-internals.md) | The cut Load Shortcut menu and loading one of its saves, the developer menu and panels, the cut mailbox |
| [online/modes/nightop-shop-internals.md](online/modes/nightop-shop-internals.md) | The shop screen (its rows, the opener, the wallet), Roxanne's choices, the cut stimpacks, the cut Shock Bolt |
| [world/matrix13-internals.md](world/matrix13-internals.md) | The cut area's rows and event spawns, the command, the arrival, Lily's menu, the camps, the save, the title, its world rows, the records |
| [world/lily-signal-internals.md](world/lily-signal-internals.md) | The rows, quests and talks of Lily's signal |
| [dev/safety.md](dev/safety.md) | Which kills and achievements count for each player; the safety design |

### Where each section went

| Section | Now in |
| --- | --- |
| Lua and native parts | [dev/architecture.md](dev/architecture.md#lua-and-native-parts) |
| Lua and native parts: The Lua scripts | [dev/architecture.md](dev/architecture.md#the-lua-scripts) |
| Lua and native parts: Files shared by Lua and the native part | [dev/architecture.md](dev/architecture.md#files-shared-by-lua-and-the-native-part) |
| The co-op UI's input | [dev/architecture.md](dev/architecture.md#the-co-op-uis-input) |
| The co-op UI's input: Controller | [dev/architecture.md](dev/architecture.md#controller) |
| The co-op UI's input: Mouse | [dev/architecture.md](dev/architecture.md#mouse) |
| The co-op UI's input: Focus watchdog | [dev/architecture.md](dev/architecture.md#focus-watchdog) |
| The co-op UI's input: Line breaks | [dev/architecture.md](dev/architecture.md#line-breaks) |
| The Steam link | [online/steam-link-internals.md](online/steam-link-internals.md) |
| The Steam link: Lobby and invites | [online/steam-link-internals.md](online/steam-link-internals.md#lobby-and-invites) |
| The Steam link: Players who are not Steam friends | [online/steam-link-internals.md](online/steam-link-internals.md#players-who-are-not-steam-friends) |
| The Steam link: Handshake | [online/steam-link-internals.md](online/steam-link-internals.md#handshake) |
| The Steam link: Channel 0: text | [online/steam-link-internals.md](online/steam-link-internals.md#channel-0-text) |
| The Steam link: Channel 1: tables and poses | [online/steam-link-internals.md](online/steam-link-internals.md#channel-1-tables-and-poses) |
| The Steam link: Protocol versions | [online/steam-link-internals.md](online/steam-link-internals.md#protocol-versions) |
| The Steam link: Link health in the log | [online/steam-link-internals.md](online/steam-link-internals.md#link-health-in-the-log) |
| The ghost pipeline | [online/partner-internals.md](online/partner-internals.md) |
| The ghost pipeline: 1. Capture | [online/partner-internals.md](online/partner-internals.md#1-capture) |
| The ghost pipeline: 2. The component table | [online/partner-internals.md](online/partner-internals.md#2-the-component-table) |
| The ghost pipeline: 3. The pose codec | [online/partner-internals.md](online/partner-internals.md#3-the-pose-codec) |
| The ghost pipeline: 4. Playback clock and interpolation | [online/partner-internals.md](online/partner-internals.md#4-playback-clock-and-interpolation) |
| The ghost pipeline: 5. The ghost, built from the table | [online/partner-internals.md](online/partner-internals.md#5-the-ghost-built-from-the-table) |
| The ghost pipeline: 6. Fallback: the base suit | [online/partner-internals.md](online/partner-internals.md#6-fallback-the-base-suit) |
| The ghost pipeline: 7. Map gate | [online/partner-internals.md](online/partner-internals.md#7-map-gate) |
| The ghost pipeline: Looks | [online/partner-internals.md](online/partner-internals.md#looks) |
| The ghost pipeline: CNS guard and crash sentinel | [online/partner-internals.md](online/partner-internals.md#cns-guard-and-crash-sentinel) |
| The ghost pipeline: Solid partner | [online/partner-internals.md](online/partner-internals.md#solid-partner) |
| The ghost pipeline: Ghost bench | [online/partner-internals.md](online/partner-internals.md#ghost-bench) |
| Same-place enemies | [fight/enemies-internals.md](fight/enemies-internals.md#same-place-enemies) |
| Same spawns | [fight/enemies-internals.md](fight/enemies-internals.md#same-spawns) |
| Same spawns: The spawn filter | [fight/enemies-internals.md](fight/enemies-internals.md#the-spawn-filter) |
| Extra enemies | [fight/enemies-internals.md](fight/enemies-internals.md#extra-enemies) |
| Shared bosses | [fight/enemies-internals.md](fight/enemies-internals.md#shared-bosses) |
| Shared quests | [online/group-internals.md](online/group-internals.md#shared-quests) |
| Following the host | [online/group-internals.md](online/group-internals.md#following-the-host) |
| The teleport screen's extra tabs | [online/group-internals.md](online/group-internals.md#the-teleport-screens-extra-tabs) |
| A player down | [online/group-internals.md](online/group-internals.md#a-player-down) |
| A player down: Revive | [online/group-internals.md](online/group-internals.md#revive) |
| Camp rests in a shared area | [online/group-internals.md](online/group-internals.md#camp-rests-in-a-shared-area) |
| Cutscene wait | [online/group-internals.md](online/group-internals.md#cutscene-wait) |
| Doro races | [online/modes/race-internals.md](online/modes/race-internals.md) |
| Doro races: The display Doro | [online/modes/race-internals.md](online/modes/race-internals.md#the-display-doro) |
| Doro races: The Doro look | [online/modes/race-internals.md](online/modes/race-internals.md#the-doro-look) |
| Doro races: The ghost's Doro mode | [online/modes/race-internals.md](online/modes/race-internals.md#the-ghosts-doro-mode) |
| Doro races: Driving | [online/modes/race-internals.md](online/modes/race-internals.md#driving) |
| Doro races: The native hold | [online/modes/race-internals.md](online/modes/race-internals.md#the-native-hold) |
| Doro races: Race lines | [online/modes/race-internals.md](online/modes/race-internals.md#race-lines) |
| Doro races: Races in a match | [online/modes/race-internals.md](online/modes/race-internals.md#races-in-a-match) |
| The cut Lion | [fight/bosses-internals.md](fight/bosses-internals.md#the-cut-lion) |
| The cut Lion: The rows | [fight/bosses-internals.md](fight/bosses-internals.md#the-rows) |
| The cut Lion: The cut stimpacks | [online/modes/nightop-shop-internals.md](online/modes/nightop-shop-internals.md#the-cut-stimpacks) |
| The cut Lion: The cut ChainSpin | [eve/eve-internals.md](eve/eve-internals.md#the-cut-chainspin) |
| The cut Lion: The cut Shock Bolt | [online/modes/nightop-shop-internals.md](online/modes/nightop-shop-internals.md#the-cut-shock-bolt) |
| The cut Lion: The spawn | [fight/bosses-internals.md](fight/bosses-internals.md#the-spawn) |
| The cut Lion: What stays out | [fight/bosses-internals.md](fight/bosses-internals.md#what-stays-out) |
| The cut Lion: The records | [world/matrix13-internals.md](world/matrix13-internals.md#the-records) |
| The cut Lion: Open questions | [fight/bosses-internals.md](fight/bosses-internals.md#open-questions-about-the-lion) |
| The cut Gardener | [fight/bosses-internals.md](fight/bosses-internals.md#the-cut-gardener) |
| The cut Gardener: Its rows | [fight/bosses-internals.md](fight/bosses-internals.md#the-gardeners-rows) |
| The cut Gardener: Its batch in the native part | [fight/bosses-internals.md](fight/bosses-internals.md#the-gardeners-batch-in-the-native-part) |
| The cut Gardener: Its spawn | [fight/bosses-internals.md](fight/bosses-internals.md#the-gardeners-spawn) |
| The cut Gardener: Open questions | [fight/bosses-internals.md](fight/bosses-internals.md#open-questions-about-the-gardener) |
| The cut Tendril | [fight/bosses-internals.md](fight/bosses-internals.md#the-cut-tendril) |
| The cut Tendril: Its rows | [fight/bosses-internals.md](fight/bosses-internals.md#the-tendrils-rows) |
| The cut Tendril: Its Shows | [fight/bosses-internals.md](fight/bosses-internals.md#the-tendrils-shows) |
| The cut Tendril: Its batch in the native part | [fight/bosses-internals.md](fight/bosses-internals.md#the-tendrils-batch-in-the-native-part) |
| The cut Tendril: Its spawn | [fight/bosses-internals.md](fight/bosses-internals.md#the-tendrils-spawn) |
| The cut Tendril: Open questions | [fight/bosses-internals.md](fight/bosses-internals.md#open-questions-about-the-tendril) |
| The cut Matrix XIII area (experimental) | [world/matrix13-internals.md](world/matrix13-internals.md) |
| The cut Matrix XIII area (experimental): Its rows | [world/matrix13-internals.md](world/matrix13-internals.md#its-rows) |
| The cut Matrix XIII area (experimental): Its event spawns | [world/matrix13-internals.md](world/matrix13-internals.md#its-event-spawns) |
| The cut Matrix XIII area (experimental): The command | [world/matrix13-internals.md](world/matrix13-internals.md#the-command) |
| The cut Matrix XIII area (experimental): The arrival and the coins | [world/matrix13-internals.md](world/matrix13-internals.md#the-arrival-and-the-coins) |
| The cut Matrix XIII area (experimental): Lily's menu | [world/matrix13-internals.md](world/matrix13-internals.md#lilys-menu) |
| The cut Matrix XIII area (experimental): The camp list | [world/matrix13-internals.md](world/matrix13-internals.md#the-camp-list) |
| The cut Matrix XIII area (experimental): The save | [world/matrix13-internals.md](world/matrix13-internals.md#the-save) |
| The cut Matrix XIII area (experimental): At the title | [world/matrix13-internals.md](world/matrix13-internals.md#at-the-title) |
| The cut Matrix XIII area (experimental): Matrix XIII's world rows | [world/matrix13-internals.md](world/matrix13-internals.md#matrix-xiiis-world-rows) |
| The cut Matrix XIII area (experimental): The camp names | [world/matrix13-internals.md](world/matrix13-internals.md#the-camp-names) |
| The cut Matrix XIII area (experimental): Open questions | [world/matrix13-internals.md](world/matrix13-internals.md#open-questions) |
| The Night Operation shop screen | [online/modes/nightop-shop-internals.md](online/modes/nightop-shop-internals.md#the-night-operation-shop-screen) |
| The Night Operation shop screen: Its rows | [online/modes/nightop-shop-internals.md](online/modes/nightop-shop-internals.md#its-rows) |
| The Night Operation shop screen: The opener | [online/modes/nightop-shop-internals.md](online/modes/nightop-shop-internals.md#the-opener) |
| The Night Operation shop screen: The wallet | [online/modes/nightop-shop-internals.md](online/modes/nightop-shop-internals.md#the-wallet) |
| Roxanne's Night Operation choices | [online/modes/nightop-shop-internals.md](online/modes/nightop-shop-internals.md#roxannes-night-operation-choices) |
| Lily's signal (experimental) | [world/lily-signal-internals.md](world/lily-signal-internals.md) |
| Developer flight and slow motion | [eve/eve-internals.md](eve/eve-internals.md#developer-flight-and-slow-motion) |
| Cut glide | [eve/eve-internals.md](eve/eve-internals.md#cut-glide) |
| Emotes | [eve/eve-internals.md](eve/eve-internals.md#emotes) |
| The cut Load Shortcut menu | [cutmenus/menus-internals.md](cutmenus/menus-internals.md#the-cut-load-shortcut-menu) |
| The cut Load Shortcut menu: Loading one | [cutmenus/menus-internals.md](cutmenus/menus-internals.md#loading-one) |
| Developer menu and panels | [cutmenus/menus-internals.md](cutmenus/menus-internals.md#developer-menu-and-panels) |
| Cut mailbox | [cutmenus/menus-internals.md](cutmenus/menus-internals.md#cut-mailbox) |
| Cut mailbox: Why the game's mailbox is not used | [cutmenus/menus-internals.md](cutmenus/menus-internals.md#why-the-games-mailbox-is-not-used) |
| Cut mailbox: The inventory read | [cutmenus/menus-internals.md](cutmenus/menus-internals.md#the-inventory-read) |
| Cut mailbox: The remove, the gift and its answer | [cutmenus/menus-internals.md](cutmenus/menus-internals.md#the-remove-the-gift-and-its-answer) |
| Achievements | [dev/safety.md](dev/safety.md#achievements) |
| Safety design | [dev/safety.md](dev/safety.md#safety-design) |
| Loopback, record and replay | [dev/architecture.md](dev/architecture.md#loopback-record-and-replay) |
