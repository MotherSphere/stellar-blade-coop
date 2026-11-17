# Documentation

To install the mod, start with [Install](../INSTALL.md); to play, with
[Playing with a friend](playing-with-a-friend.md). The pages under [Building and internals](#building-and-internals)
describe the code, for anyone who builds the mod or changes it. Stellar Blade Online was first called StellarCoop, and
its folder, its DLL, its `[StellarCoop]` log tags and its release zip keep that name; its console commands still
start with `coop`.

## Install and play

| Page | What it covers |
| --- | --- |
| [Install](../INSTALL.md) | Install, update and uninstall on Windows, Linux and the Steam Deck; saves and Steam Cloud; which logs to send |
| [Features and test status](features.md) | The features with their test status, the dated two-PC tests and which versions link together |
| [Playing with a friend](playing-with-a-friend.md) | Hosting and joining, join codes, following the host, the revive, co-op saves, synced photo mode, shared quests |
| [Shared world](shared-world.md) | Doors, levers, lifts and shortcuts one player works changing in the other's game; what stays each player's own; the setting and `coop world` |
| [Story together](story-together.md) | The host's cutscenes and talks played in the guest's game with his choices, QTE results and skips; story trips; quest steps the guest makes first; the setting and `coop scenes` |
| [SBO lobby and matches](sbo-lobby.md) | The recruiter's Join, the lobby menu, Search, private matches, the countdown, leaving, the hall lobbies, the PvP test, the link protocol |
| [Interface](interface.md) | The co-op menu, the session chat, the partner HUD, the guide, the teleport screen, notices |
| [Ghost](ghost.md) | The ghost's looks, .pak mods and CNS outfits, the solid partner |
| [Shared enemies](shared-enemies.md) | Shared enemies, same place, same spawns, the spawn filter, extra enemies, shared bosses |
| [Doro races](doro-races.md) | Recording a track, starting a race, driving, rules, results, the Doro look, track files |
| [The bike](bike.md) | Getting on and off, the refusals, riding, `coop bike`, the settings, the ghosts, credits to Eve On Wheels |
| [Gun mode](gun-mode.md) | The NIKKE rifle outside its missions: standing and crouched, firing, the laser sight, the keys, `coop gun`, the settings, building its paks, credits |
| [Settings](settings.md) | `coop-settings.txt` as the mod writes it, the files in the mod folder |
| [Keys and commands](usage.md) | Every key and `coop` console command, the F6 and `coop status` lines, and the new place of each section that moved |
| [Saves](saves.md) | What the mod reads and writes, backups, Steam Cloud, the co-op saves, recovery |
| [Troubleshooting](troubleshooting.md) | Where to look, problems grouped by topic, the 60 s link lines, which logs to send |

## Night Operation

| Page | What it covers |
| --- | --- |
| [Night Operation](night-operation.md) | The cut mode, the plan, the solo run, the co-op run, credits |
| [Reward shop](night-operation-shop.md) | The points, the seven items, the shop screen, Roxanne's choices, the cut Shock Bolt |
| [Challenges](challenges.md) | `coop challenge`, Target Practice, the Shooting Range alone and for two, score, best runs |
| [Night Operation previews](night-operation-previews.md) | The probe (`coop no`), the recruiter (`coop recruiter`), how the original matchmaking is blocked |

## Cut content

| Page | What it covers |
| --- | --- |
| [Cut enemies](cut-enemies.md) | The cut model viewer and its free camera, the Lion as a boss, the Gardener and Tendril fights |
| [EVE's cut moves](cut-eve.md) | `coop chainspin`, `coop wear`, `coop emote`, `coop fly`, `coop slowmo`, `coop glide` |
| [Cut scenes and menus](cut-scenes-and-menus.md) | `coop scene`, `coop lines`, `coop shortcut`, `coop devmenu` and `coop devinfo`, `coop gift` |
| [Matrix XIII](matrix-xiii.md) | The cut dungeon, `coop mxiii` and its test pak |
| [Lily's signal](lily-signal.md) | The mod's two quests that lead through Matrix XIII, their talks, lines and status lines |

## Building and internals

The game addresses in the internals pages are build 26123051's, the build the code pins. They were read on build
24463856 and matched to their build 26123051 values by comparing the two executables; none of the old addresses is
left. The pages still name build 24463856 where a fact was read on that build, such as the table dumps.

| Page | What it covers |
| --- | --- |
| [Building](building.md) | Toolchain, `tools/install.py`, `tools/wine_smoke.py`, the reproducible build, releases, repository layout |
| [Tests](tests.md) | The Lua, C++ and Python tests and what each one checks |
| [How it works](how-it-works.md) | Index of the internals pages, and where each section of the old single page went |
| [Architecture](internals/architecture.md) | The Lua and native parts, the Lua scripts, the files they share, the co-op UI's input, loopback, record and replay |
| [The Steam link](internals/steam-link.md) | Lobby and invites, the handshake, channels 0 and 1, protocol versions, link health |
| [The ghost pipeline](internals/ghost.md) | The ghost in seven steps, looks, the CNS guard and crash sentinel, the solid partner |
| [Shared enemies: how they work](internals/shared-enemies.md) | Same-place enemies, same spawns and the spawn filter, extra enemies, shared bosses |
| [Group play: how it works](internals/group-play.md) | Shared quests, following the host, the teleport screen, the revive, camp rests, the cutscene wait |
| [Shared world: how it works](internals/shared-world.md) | The four roots and their hooks, the generated filter, the SBW lines, how her changes are made, the status line, the addresses |
| [Story together: how it works](internals/story-sync.md) | The host's theater reads and hooks, the scene and trip tables, the SBS lines, the guest's gate, leash and results, the guest's quest steps, the status line, the addresses |
| [Doro races: how they work](internals/doro-races.md) | The display Doro, the Doro look, the ghost's Doro mode, driving, race lines |
| [Day and night: how it works](internals/daynight.md) | The shared UTC clock, the sun and moon, the dawn and dusk ramps, the map table, the rules, the env fields the native part writes, the request and status line, the cost |
| [The bike: how it works](internals/bike.md) | The preload, the part on EVE, mount and dismount, the gate, the riding pose, the riding model, the lean, the ghosts |
| [Cut enemies: how they are added](internals/cut-enemies.md) | The cut Lion with the row batches, the cut Gardener, the cut Tendril |
| [EVE's cut moves: how they work](internals/cut-eve.md) | The cut ChainSpin, developer flight and slow motion, the cut glide, emotes |
| [Cut menus and the mailbox: how they work](internals/cut-menus.md) | The cut Load Shortcut menu, the developer menu and panels, the cut mailbox |
| [Night Operation's shop: how it works](internals/night-operation-shop.md) | The shop screen and its wallet, Roxanne's choices, the cut stimpacks, the cut Shock Bolt |
| [Matrix XIII: how it works](internals/matrix-xiii.md) | The cut dungeon's rows, event spawns, arrival, camps, save, title and world rows |
| [Lily's signal: how it works](internals/lily-signal.md) | The rows, quests and talks of Lily's signal |
| [Achievements and safety design](internals/safety.md) | Which kills and achievements count for each player, the safety design |
| [Story dump](story.md) | `coop story`, `tools/story_lines.py` and `tools/save_read.py`: the story state of a save or of the running game, one line per value |
