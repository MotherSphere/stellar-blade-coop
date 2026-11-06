# Documentation

These pages describe Stellar Blade Online. Its folder, its DLL, its `coop` console commands and this repository still
use its first name, StellarCoop. To install the mod, start with [INSTALL.md](../INSTALL.md); to play, with
[Playing with a friend](playing-with-a-friend.md). The pages under [Building and internals](#building-and-internals)
describe the code, for anyone who builds the mod or changes it.

## Install and play

| Page | What it covers |
| --- | --- |
| [INSTALL.md](../INSTALL.md) | Requirements, install on Windows and on Linux or the Steam Deck, update, other mods, keys and settings, turning the mod off or on, saves and Steam Cloud, co-op saves, recovery, checking the files, uninstall, which logs to send |
| [Features](features.md) | Every feature with its test status, the dated two-PC tests and which versions link together |
| [Playing with a friend](playing-with-a-friend.md) | Hosting and joining, join codes, following the host, a player down and the revive, camp rests, known limits, co-op saves, synced photo mode, the cutscene wait, shared quests |
| [Interface](interface.md) | The co-op menu with the co-op line, controller, mouse and Options, the session chat, the partner HUD, the guide, the teleport screen, notices |
| [Ghost](ghost.md) | Your friend's ghost: the `cloth`, `dyes` and `effects` looks, .pak mods and CNS outfits, the solid partner |
| [Shared enemies](shared-enemies.md) | Shared enemies, same place, same spawns, the spawn filter, extra enemies, shared bosses |
| [Doro races](doro-races.md) | Recording a track, starting a race, driving, rules, results, the Doro look, track files |
| [Settings](settings.md) | `coop-settings.txt` as the mod writes it, the files in the mod folder |
| [Keys and commands](usage.md) | The keys, the `coop` console commands, the status lines, and where each section of the old guide went |
| [Saves](saves.md) | What the mod reads and writes, where the saves are, backups, Steam Cloud, the co-op saves, the manual co-op slot, recovery |

## Night Operation

| Page | What it covers |
| --- | --- |
| [Night Operation](night-operation.md) | The cut mode, what the game files hold, the plan, the solo run with its waves, levels and score, the co-op run |
| [Reward shop](night-operation-shop.md) | The points, the seven items, the shop screen, `coop nightop buy`, Roxanne's choices, the cut Shock Bolt, status lines |
| [Challenges](challenges.md) | `coop challenge`, Target Practice, the Shooting Range alone and for two, score, best runs |
| [Night Operation previews](night-operation-previews.md) | The probe (`coop no`), the recruiter (`coop recruiter`), how the original matchmaking is blocked |

## Cut content

| Page | What it covers |
| --- | --- |
| [Cut enemies](cut-enemies.md) | The cut model viewer and its free camera, the Lion as a boss, the Gardener and Tendril fights |
| [EVE's cut moves](cut-eve.md) | `coop chainspin`, `coop wear`, `coop emote`, `coop fly`, `coop slowmo`, `coop glide` |
| [Cut scenes and menus](cut-scenes-and-menus.md) | `coop scene`, `coop lines`, `coop shortcut`, `coop devmenu` and `coop devinfo`, `coop gift` |
| [Matrix XIII](matrix-xiii.md) | The cut Matrix XIII dungeon, `coop mxiii` and its test pak |
| [Lily's signal](lily-signal.md) | The mod's two quests that lead through Matrix XIII, their talks, lines and status lines |

## Help

| Page | What it covers |
| --- | --- |
| [Troubleshooting](troubleshooting.md) | Where to look, problems grouped by topic, the 60 s link lines, which logs to send |

## Building and internals

| Page | What it covers |
| --- | --- |
| [Building](building.md) | Toolchain, `tools/install.py`, `tools/wine_smoke.py`, the reproducible build, releases, repository layout |
| [Tests](tests.md) | The Lua, C++ and Python tests and what each one checks |
| [Story](story.md) | Where the save keeps the story and world state, the tool that snapshots and diffs it, the live dump (`coop story`) |
| [How it works](how-it-works.md) | Index of the internals pages, and where each section of the old single page went |
| [Architecture](internals/architecture.md) | The Lua and native parts, the Lua scripts, the files they share, the co-op UI's input, loopback, record and replay |
| [The Steam link](internals/steam-link.md) | Lobby and invites, players who are not Steam friends, the handshake, channels 0 and 1, protocol versions, link health |
| [The ghost pipeline](internals/ghost.md) | The ghost in seven steps, looks, the CNS guard and crash sentinel, the solid partner |
| [Shared enemies](internals/shared-enemies.md) | Same-place enemies, same spawns and the spawn filter, extra enemies, shared bosses |
| [Group play](internals/group-play.md) | Shared quests, following the host, the teleport screen's extra tabs, a player down and the revive, camp rests, the cutscene wait |
| [Doro races](internals/doro-races.md) | The display Doro, the Doro look, the ghost's Doro mode, driving, race lines |
| [Cut enemies](internals/cut-enemies.md) | The cut Lion with the row batches, the cut Gardener, the cut Tendril |
| [EVE's cut moves](internals/cut-eve.md) | The cut ChainSpin, developer flight and slow motion, the cut glide, emotes |
| [Cut menus and the mailbox](internals/cut-menus.md) | The cut Load Shortcut menu, the developer menu and panels, the cut mailbox |
| [Night Operation's shop](internals/night-operation-shop.md) | The shop screen and its wallet, Roxanne's choices, the cut stimpacks, the cut Shock Bolt |
| [Matrix XIII](internals/matrix-xiii.md) | The cut dungeon's rows, event spawns, arrival, Lily's menu, camps, save, title and world rows |
| [Lily's signal](internals/lily-signal.md) | The rows, quests and talks of Lily's signal |
| [Achievements and safety](internals/safety.md) | Which kills and achievements count for each player, the safety design |
