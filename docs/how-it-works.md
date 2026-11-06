# How Stellar Blade Online works

For the commands, see [usage.md](usage.md). For the code layout, see [building.md](building.md#repository-layout).

Each internals topic has its own page in `docs/internals/`: how the code does what the player pages describe, for anyone
who reads or changes the code. Code comments still cite sections of this page by name, for example
`native/src/lion/mxiii_rows.h` and `tools/mxiii_rows.py` ("Matrix XIII's world rows") and
`mod/StellarCoop/Scripts/cut/mailbox.lua` ("Achievements"), so [Where each section went](#where-each-section-went) gives
the new place of every section that used to be here.

## The internals pages

| Page | What it covers |
| --- | --- |
| [architecture.md](internals/architecture.md) | The Lua and native parts, the Lua scripts, the files they share, the co-op UI's input, loopback, record and replay |
| [steam-link.md](internals/steam-link.md) | Lobby and invites, players who are not Steam friends, the handshake, channels 0 and 1, protocol versions, link health in the log |
| [ghost.md](internals/ghost.md) | The ghost pipeline in seven steps, looks, the CNS guard and crash sentinel, the solid partner |
| [shared-enemies.md](internals/shared-enemies.md) | Same-place enemies, same spawns and the spawn filter, extra enemies, shared bosses |
| [group-play.md](internals/group-play.md) | Shared quests, following the host, the teleport screen's extra tabs, a player down and the revive, camp rests, the cutscene wait |
| [doro-races.md](internals/doro-races.md) | The display Doro, the Doro look, the ghost's Doro mode, driving, race lines |
| [cut-enemies.md](internals/cut-enemies.md) | The cut Lion with the row batches, the cut Gardener, the cut Tendril |
| [cut-eve.md](internals/cut-eve.md) | The cut ChainSpin, developer flight and slow motion, the cut glide, emotes |
| [cut-menus.md](internals/cut-menus.md) | The cut Load Shortcut menu and loading one of its saves, the developer menu and panels, the cut mailbox |
| [night-operation-shop.md](internals/night-operation-shop.md) | The shop screen (its rows, the opener, the wallet), Roxanne's choices, the cut stimpacks, the cut Shock Bolt |
| [matrix-xiii.md](internals/matrix-xiii.md) | The cut dungeon's rows and event spawns, the command, the arrival, Lily's menu, the camps, the save, the title, its world rows, the records |
| [lily-signal.md](internals/lily-signal.md) | The rows, quests and talks of Lily's signal |
| [safety.md](internals/safety.md) | Which kills and achievements count for each player, and the safety design |

## Where each section went

| Section | Now in |
| --- | --- |
| Lua and native parts | [internals/architecture.md](internals/architecture.md#lua-and-native-parts) |
| Lua and native parts: The Lua scripts | [internals/architecture.md](internals/architecture.md#the-lua-scripts) |
| Lua and native parts: Files shared by Lua and the native part | [internals/architecture.md](internals/architecture.md#files-shared-by-lua-and-the-native-part) |
| The co-op UI's input | [internals/architecture.md](internals/architecture.md#the-co-op-uis-input) |
| The co-op UI's input: Controller | [internals/architecture.md](internals/architecture.md#controller) |
| The co-op UI's input: Mouse | [internals/architecture.md](internals/architecture.md#mouse) |
| The co-op UI's input: Focus watchdog | [internals/architecture.md](internals/architecture.md#focus-watchdog) |
| The co-op UI's input: Line breaks | [internals/architecture.md](internals/architecture.md#line-breaks) |
| The Steam link | [internals/steam-link.md](internals/steam-link.md) |
| The Steam link: Lobby and invites | [internals/steam-link.md](internals/steam-link.md#lobby-and-invites) |
| The Steam link: Players who are not Steam friends | [internals/steam-link.md](internals/steam-link.md#players-who-are-not-steam-friends) |
| The Steam link: Handshake | [internals/steam-link.md](internals/steam-link.md#handshake) |
| The Steam link: Channel 0: text | [internals/steam-link.md](internals/steam-link.md#channel-0-text) |
| The Steam link: Channel 1: tables and poses | [internals/steam-link.md](internals/steam-link.md#channel-1-tables-and-poses) |
| The Steam link: Protocol versions | [internals/steam-link.md](internals/steam-link.md#protocol-versions) |
| The Steam link: Link health in the log | [internals/steam-link.md](internals/steam-link.md#link-health-in-the-log) |
| The ghost pipeline | [internals/ghost.md](internals/ghost.md) |
| The ghost pipeline: 1. Capture | [internals/ghost.md](internals/ghost.md#1-capture) |
| The ghost pipeline: 2. The component table | [internals/ghost.md](internals/ghost.md#2-the-component-table) |
| The ghost pipeline: 3. The pose codec | [internals/ghost.md](internals/ghost.md#3-the-pose-codec) |
| The ghost pipeline: 4. Playback clock and interpolation | [internals/ghost.md](internals/ghost.md#4-playback-clock-and-interpolation) |
| The ghost pipeline: 5. The ghost, built from the table | [internals/ghost.md](internals/ghost.md#5-the-ghost-built-from-the-table) |
| The ghost pipeline: 6. Fallback: the base suit | [internals/ghost.md](internals/ghost.md#6-fallback-the-base-suit) |
| The ghost pipeline: 7. Map gate | [internals/ghost.md](internals/ghost.md#7-map-gate) |
| The ghost pipeline: Looks | [internals/ghost.md](internals/ghost.md#looks) |
| The ghost pipeline: CNS guard and crash sentinel | [internals/ghost.md](internals/ghost.md#cns-guard-and-crash-sentinel) |
| The ghost pipeline: Solid partner | [internals/ghost.md](internals/ghost.md#solid-partner) |
| Same-place enemies | [internals/shared-enemies.md](internals/shared-enemies.md#same-place-enemies) |
| Same spawns | [internals/shared-enemies.md](internals/shared-enemies.md#same-spawns) |
| Same spawns: The spawn filter | [internals/shared-enemies.md](internals/shared-enemies.md#the-spawn-filter) |
| Extra enemies | [internals/shared-enemies.md](internals/shared-enemies.md#extra-enemies) |
| Shared bosses | [internals/shared-enemies.md](internals/shared-enemies.md#shared-bosses) |
| Shared quests | [internals/group-play.md](internals/group-play.md#shared-quests) |
| Following the host | [internals/group-play.md](internals/group-play.md#following-the-host) |
| The teleport screen's extra tabs | [internals/group-play.md](internals/group-play.md#the-teleport-screens-extra-tabs) |
| A player down | [internals/group-play.md](internals/group-play.md#a-player-down) |
| A player down: Revive | [internals/group-play.md](internals/group-play.md#revive) |
| Camp rests in a shared area | [internals/group-play.md](internals/group-play.md#camp-rests-in-a-shared-area) |
| Cutscene wait | [internals/group-play.md](internals/group-play.md#cutscene-wait) |
| Doro races | [internals/doro-races.md](internals/doro-races.md) |
| Doro races: The display Doro | [internals/doro-races.md](internals/doro-races.md#the-display-doro) |
| Doro races: The Doro look | [internals/doro-races.md](internals/doro-races.md#the-doro-look) |
| Doro races: The ghost's Doro mode | [internals/doro-races.md](internals/doro-races.md#the-ghosts-doro-mode) |
| Doro races: Driving | [internals/doro-races.md](internals/doro-races.md#driving) |
| Doro races: Race lines | [internals/doro-races.md](internals/doro-races.md#race-lines) |
| The cut Lion | [internals/cut-enemies.md](internals/cut-enemies.md#the-cut-lion) |
| The cut Lion: The rows | [internals/cut-enemies.md](internals/cut-enemies.md#the-rows) |
| The cut Lion: The cut stimpacks | [internals/night-operation-shop.md](internals/night-operation-shop.md#the-cut-stimpacks) |
| The cut Lion: The cut ChainSpin | [internals/cut-eve.md](internals/cut-eve.md#the-cut-chainspin) |
| The cut Lion: The cut Shock Bolt | [internals/night-operation-shop.md](internals/night-operation-shop.md#the-cut-shock-bolt) |
| The cut Lion: The spawn | [internals/cut-enemies.md](internals/cut-enemies.md#the-spawn) |
| The cut Lion: What stays out | [internals/cut-enemies.md](internals/cut-enemies.md#what-stays-out) |
| The cut Lion: The records | [internals/matrix-xiii.md](internals/matrix-xiii.md#the-records) |
| The cut Lion: Open questions | [internals/cut-enemies.md](internals/cut-enemies.md#open-questions) |
| The cut Gardener | [internals/cut-enemies.md](internals/cut-enemies.md#the-cut-gardener) |
| The cut Gardener: Its rows | [internals/cut-enemies.md](internals/cut-enemies.md#its-rows) |
| The cut Gardener: Its batch in the native part | [internals/cut-enemies.md](internals/cut-enemies.md#its-batch-in-the-native-part) |
| The cut Gardener: Its spawn | [internals/cut-enemies.md](internals/cut-enemies.md#its-spawn) |
| The cut Gardener: Open questions | [internals/cut-enemies.md](internals/cut-enemies.md#open-questions-1) |
| The cut Tendril | [internals/cut-enemies.md](internals/cut-enemies.md#the-cut-tendril) |
| The cut Tendril: Its rows | [internals/cut-enemies.md](internals/cut-enemies.md#its-rows-1) |
| The cut Tendril: Its Shows | [internals/cut-enemies.md](internals/cut-enemies.md#its-shows) |
| The cut Tendril: Its batch in the native part | [internals/cut-enemies.md](internals/cut-enemies.md#its-batch-in-the-native-part-1) |
| The cut Tendril: Its spawn | [internals/cut-enemies.md](internals/cut-enemies.md#its-spawn-1) |
| The cut Tendril: Open questions | [internals/cut-enemies.md](internals/cut-enemies.md#open-questions-2) |
| The cut Matrix XIII dungeon (experimental) | [internals/matrix-xiii.md](internals/matrix-xiii.md) |
| The cut Matrix XIII dungeon (experimental): Its rows | [internals/matrix-xiii.md](internals/matrix-xiii.md#its-rows) |
| The cut Matrix XIII dungeon (experimental): Its event spawns | [internals/matrix-xiii.md](internals/matrix-xiii.md#its-event-spawns) |
| The cut Matrix XIII dungeon (experimental): The command | [internals/matrix-xiii.md](internals/matrix-xiii.md#the-command) |
| The cut Matrix XIII dungeon (experimental): The arrival and the coins | [internals/matrix-xiii.md](internals/matrix-xiii.md#the-arrival-and-the-coins) |
| The cut Matrix XIII dungeon (experimental): Lily's menu | [internals/matrix-xiii.md](internals/matrix-xiii.md#lilys-menu) |
| The cut Matrix XIII dungeon (experimental): The camp list | [internals/matrix-xiii.md](internals/matrix-xiii.md#the-camp-list) |
| The cut Matrix XIII dungeon (experimental): The save | [internals/matrix-xiii.md](internals/matrix-xiii.md#the-save) |
| The cut Matrix XIII dungeon (experimental): At the title | [internals/matrix-xiii.md](internals/matrix-xiii.md#at-the-title) |
| The cut Matrix XIII dungeon (experimental): Matrix XIII's world rows | [internals/matrix-xiii.md](internals/matrix-xiii.md#matrix-xiiis-world-rows) |
| The cut Matrix XIII dungeon (experimental): The camp names | [internals/matrix-xiii.md](internals/matrix-xiii.md#the-camp-names) |
| The cut Matrix XIII dungeon (experimental): Open questions | [internals/matrix-xiii.md](internals/matrix-xiii.md#open-questions) |
| The Night Operation shop screen | [internals/night-operation-shop.md](internals/night-operation-shop.md#the-night-operation-shop-screen) |
| The Night Operation shop screen: Its rows | [internals/night-operation-shop.md](internals/night-operation-shop.md#its-rows) |
| The Night Operation shop screen: The opener | [internals/night-operation-shop.md](internals/night-operation-shop.md#the-opener) |
| The Night Operation shop screen: The wallet | [internals/night-operation-shop.md](internals/night-operation-shop.md#the-wallet) |
| Roxanne's Night Operation choices | [internals/night-operation-shop.md](internals/night-operation-shop.md#roxannes-night-operation-choices) |
| Lily's signal (experimental) | [internals/lily-signal.md](internals/lily-signal.md) |
| Developer flight and slow motion | [internals/cut-eve.md](internals/cut-eve.md#developer-flight-and-slow-motion) |
| Cut glide | [internals/cut-eve.md](internals/cut-eve.md#cut-glide) |
| Emotes | [internals/cut-eve.md](internals/cut-eve.md#emotes) |
| The cut Load Shortcut menu | [internals/cut-menus.md](internals/cut-menus.md#the-cut-load-shortcut-menu) |
| The cut Load Shortcut menu: Loading one | [internals/cut-menus.md](internals/cut-menus.md#loading-one) |
| Developer menu and panels | [internals/cut-menus.md](internals/cut-menus.md#developer-menu-and-panels) |
| Cut mailbox | [internals/cut-menus.md](internals/cut-menus.md#cut-mailbox) |
| Cut mailbox: Why the game's mailbox is not used | [internals/cut-menus.md](internals/cut-menus.md#why-the-games-mailbox-is-not-used) |
| Cut mailbox: The inventory read | [internals/cut-menus.md](internals/cut-menus.md#the-inventory-read) |
| Cut mailbox: The remove, the gift and its answer | [internals/cut-menus.md](internals/cut-menus.md#the-remove-the-gift-and-its-answer) |
| Achievements | [internals/safety.md](internals/safety.md#achievements) |
| Safety design | [internals/safety.md](internals/safety.md#safety-design) |
| Loopback, record and replay | [internals/architecture.md](internals/architecture.md#loopback-record-and-replay) |
