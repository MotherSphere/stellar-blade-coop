# Stellar Blade Online

<img align="right" width="200" src="mod/StellarCoop/Assets/MotherSphere.png" alt="Mother Sphere, illustration by timediffer24">

**Two-player online co-op for Stellar Blade on PC, linked through Steam.**

Each player sees the other's EVE in their own world. Stellar Blade Online is a UE4SS mod made of Lua scripts and a
native DLL. The link between the two games goes through the Steam client that the game already runs, so the mod needs
no other program and no server of its own. It was called StellarCoop until October 2026: the mod's folder, its DLL, its
`coop` console commands and this repository keep that name.

[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/MotherSphere/stellar-blade-coop?include_prereleases&label=release)](https://github.com/MotherSphere/stellar-blade-coop/releases)
[![Game: Stellar Blade on Steam (PC)](https://img.shields.io/badge/game-Stellar%20Blade%20%28Steam%2C%20PC%29-informational)](https://store.steampowered.com/app/3489700/)
[![Platforms: Windows, Linux with Proton](https://img.shields.io/badge/platforms-windows%20%7C%20linux%20%28proton%29-lightgrey)](#requirements)

<!-- Screenshots: drop PNG files into docs/screenshots/ and replace the comment below. -->
<!--
![The co-op menu](docs/screenshots/menu.png)
![Your friend's ghost and the partner card](docs/screenshots/ghost.png)
-->

---

## Status

Version 0.8.0 is an experimental beta. It runs on Stellar Blade's Steam build 24463856 only. On 2026-11-05 Steam
updated the game to build 26123051. 0.8.0 does not support that build, and the mod needs an update for it. On another
build, `coop status` shows `engine=off reason=build stamp ...` (or `reason=code bytes differ`), and the ghost, the
co-op saves and every other feature that reads the game's memory stay off. [INSTALL.md: Update](INSTALL.md#update)
says how to keep Steam from updating the game.

Two-PC co-op was first played on 2026-10-17, one PC on Linux with Proton and one on Windows. On 2026-10-21 two players
on 0.4.0 played on the automatic co-op saves with shared enemies and same place. On 2026-11-01 two PCs played
0.7.0-beta.1 with its ghost fix: joining with CNS packs no longer crashed. The features added since 0.4, among them
shared quests, the friend's revive, Night Operation and Doro races, have not been tested between two PCs.
[docs/features.md](docs/features.md#status) has the full test history and the status of each feature.

0.8.0 uses link protocol 19 and does not link with 0.7.5 (protocol 18) or older versions.

## Install

1. Install UE4SS for Stellar Blade ("Stellar Blade UE4SS 1.3").
2. Download `StellarCoop-<version>.zip` from the
   [Releases](https://github.com/MotherSphere/stellar-blade-coop/releases) page, unzip it, and copy the `StellarCoop`
   folder into `SB/Binaries/Win64/ue4ss/Mods/` in the game folder.
3. Start the game, load a save and press F6. The screen shows `Co-op: not in a session.`

Close the game before you copy, change or delete any mod file. [INSTALL.md](INSTALL.md) has the full guide.

| Setup | Notes | Guide |
| --- | --- | --- |
| Windows | The three steps above. If Windows Defender quarantines `StellarCoop.dll`, `UE4SS.log` says `Native part not loaded` and the keys do not work. | [Install](INSTALL.md#install), [Windows Defender and SmartScreen](INSTALL.md#windows-defender-and-smartscreen) |
| Linux with Proton, Steam Deck | The same zip. If UE4SS never starts, set the game's Steam launch options to `WINEDLLOVERRIDES="dwmapi=n,b" %command%`. | [Linux and Steam Deck](INSTALL.md#linux-and-steam-deck) |
| From source, on Linux | `python3 tools/install.py [--game <Stellar Blade folder>]` runs the checks, builds the DLL with clang-cl and copies the mod. It backs up the files it replaces into `~/StellarCoop-install-backups`. | [Building from source](docs/building.md) |

## What it does

- F5 opens the co-op menu. Host a session creates a Steam lobby for 2 players and opens the Steam invite dialog.
  Options can limit the session to invited friends, or open it to anyone who has its 7-character join code. On an
  XInput controller, View held for 1 s opens the menu. See [interface.md](docs/interface.md) and
  [playing-with-a-friend.md](docs/playing-with-a-friend.md).
- Your friend's EVE appears in your world as a ghost: a display-only copy that moves as she moves, wears her outfit and
  has your friend's Steam name above it. Items are not shared, except the consumables sent with `coop gift`. See
  [ghost.md](docs/ghost.md).
- Your friend's card at the top left shows their ping, map, HP, shield and Beta. During a session, Enter opens a chat
  box. See [interface.md](docs/interface.md#partner-hud).
- Shared enemies (experimental, on by default) give each common enemy one HP bar and one death in both games, while
  both players play a co-op save. Same place, same spawns and shared bosses build on it, and the host's settings decide
  them for both games. See [shared-enemies.md](docs/shared-enemies.md).
- Co-op saves are copies of your saves (`StellarBladeCoop00.sav` to `04.sav`) that the mod makes at the title. Night
  Operation, the challenges, shared enemies and shared quests run on them only, and nothing goes back to your own saves
  unless you export it. See [playing-with-a-friend.md](docs/playing-with-a-friend.md#co-op-saves) and
  [saves.md](docs/saves.md).
- Group play, not tested in game yet: F7 to travel to the camp nearest the host (off until tested), the friend's revive
  (experimental, off by default), a pause while a cutscene plays in the host's game, and shared quests (experimental,
  off by default). See [playing-with-a-friend.md](docs/playing-with-a-friend.md).
- Doro races: record a track with F9 checkpoints, then race it alone or against your friend, each racer drawn as a
  Doro. Not tested in game yet. See [doro-races.md](docs/doro-races.md).
- Night Operation is a multiplayer wave-survival mode that Shift Up cut before release. `coop nightop start` runs five
  timed waves with an 8-minute timer and a score, alone or for both players, and its points buy items in a reward shop.
  `coop challenge` runs five short fights on the same code. The shop screen ran in game on 2026-10-27. One solo run on
  2026-10-28 spawned its waves but tracked none of them, and the fixes are untested. See
  [night-operation.md](docs/night-operation.md), [night-operation-shop.md](docs/night-operation-shop.md) and
  [challenges.md](docs/challenges.md).
- Content cut from the game but still in its files: a viewer for Leviathan and other cut models, the cut Lion boss to
  fight (`coop lion`), the Gardener and the Tendril, cut hairs and suits (`coop wear`), emotes, the developer flight
  and glide, cut scenes and subtitles, the Load Shortcut saves and the developer menu. The Leviathan viewer ran in game
  on 2026-10-22 and the Lion was fought on 2026-10-24. See [cut-enemies.md](docs/cut-enemies.md),
  [cut-eve.md](docs/cut-eve.md) and [cut-scenes-and-menus.md](docs/cut-scenes-and-menus.md).
- The cut Matrix XIII dungeon (`coop mxiii`, experimental), and Lily's signal: two quests of the mod's own, the second
  of which leads through that dungeon. Lily's signal has not been tried in game yet. Both need the zMXIII_P test pak,
  which does not come with the mod. See [matrix-xiii.md](docs/matrix-xiii.md) and
  [lily-signal.md](docs/lily-signal.md).
- Solo test tools run the whole ghost pipeline on one PC: a network loopback, and a recording with its replay. See
  [usage.md](docs/usage.md#solo-testing-loopback-record-replay).

[docs/features.md](docs/features.md) describes every feature with its test status.

## Requirements

| Requirement | Details |
| --- | --- |
| Game | Stellar Blade on Steam (PC), game build 24463856. [INSTALL.md: Update](INSTALL.md#update) says how to keep Steam from updating the game before the mod supports the new build. |
| UE4SS | v3.0.1 Beta, as packaged in "Stellar Blade UE4SS 1.3". |
| System | Windows, or Linux with Proton. |
| Console | Optional: ConsoleEnablerMod (in that UE4SS package) for the `coop` console commands. The keys work without it. |
| Playing together | Both players need the same mod protocol (19 in this version) and the same game build. |

## Documentation

Every page is in [docs/](docs/).

| Document | For | What it covers |
| --- | --- | --- |
| [INSTALL.md](INSTALL.md) | Players | Install, update, check the files, co-op saves, uninstall, which logs to send |
| [Features](docs/features.md) | Players | Every feature with its test status, the two-PC tests, protocol versions |
| [Playing with a friend](docs/playing-with-a-friend.md) | Players | Hosting and joining, join codes, following the host, revive, co-op saves, synced photo mode, shared quests |
| [Interface](docs/interface.md) | Players | The co-op menu, controller and mouse, chat, partner HUD, guide, teleport screen, notices |
| [Ghost](docs/ghost.md) | Players | Your friend's ghost: looks, .pak mods and CNS outfits, solid partner |
| [Shared enemies](docs/shared-enemies.md) | Players | Shared enemies, same place, same spawns, spawn filter, extra enemies, shared bosses |
| [Doro races](docs/doro-races.md) | Players | Recording a track, racing, driving, results, track files |
| [Settings](docs/settings.md) | Players | `coop-settings.txt` and the files in the mod folder |
| [Keys and commands](docs/usage.md) | Players | Keys, every `coop` console command, status lines |
| [Saves](docs/saves.md) | Players | Save safety, backups, Steam Cloud, the co-op saves, recovery |
| [Troubleshooting](docs/troubleshooting.md) | Players | Common problems and which logs to send |
| [Night Operation](docs/night-operation.md) | Players | The cut mode, the plan, the solo run and the co-op run |
| [Reward shop](docs/night-operation-shop.md) | Players | The shop screen, `coop nightop buy`, Roxanne's choices, the Shock Bolt |
| [Challenges](docs/challenges.md) | Players | `coop challenge`, Target Practice, the Shooting Range, best runs |
| [Night Operation previews](docs/night-operation-previews.md) | Players | `coop no`, `coop recruiter`, how the original matchmaking is blocked |
| [Cut enemies](docs/cut-enemies.md) | Players | The cut model viewer, the Lion, the Gardener and the Tendril |
| [EVE's cut moves](docs/cut-eve.md) | Players | `coop chainspin`, `coop wear`, `coop emote`, `coop fly`, `coop slowmo`, `coop glide` |
| [Cut scenes and menus](docs/cut-scenes-and-menus.md) | Players | `coop scene`, `coop lines`, `coop shortcut`, the developer menu, `coop gift` |
| [Matrix XIII](docs/matrix-xiii.md) | Players | The cut dungeon and `coop mxiii` |
| [Lily's signal](docs/lily-signal.md) | Players | The mod's two quests that lead to Matrix XIII |
| [Story](docs/story.md) | Developers | Where the save keeps the story and world state (quests, mission records, zones, doors), the tool that snapshots and diffs it, and the read-only live dump (`coop story`) |
| [Building](docs/building.md) | Developers | Toolchain, `tools/install.py`, the reproducible build, releases, repository layout |
| [Tests](docs/tests.md) | Developers | The Lua, native and tool tests, which run without the game |
| [How it works](docs/how-it-works.md) | Developers | The Steam link, the ghost pipeline, safety design, loopback and replay, and the other internals in `docs/internals/` |

## Disclaimer

Stellar Blade Online is an unofficial fan mod. It is not affiliated with or endorsed by SHIFT UP or Sony Interactive
Entertainment. Stellar Blade and its assets belong to their owners. This repository contains no game files; the mod
runs on your own copy of the game.

## Credits

Night Operation's run (`coop nightop`), the challenges (`coop challenge`), which run on the same code, and the friend's
revive adapt code from [Survival Protocol](https://www.nexusmods.com/stellarblade/mods/4009) by SchizoEffective (Nexus
Mods, Stellar Blade mod 4009), used with the author's permission and distributed here under GPL-3.0-or-later. The
challenge list follows Survival Protocol's graded stages, its five difficulty stages picked from a list before a fight.
The adapted parts are:

- sending a new monster at EVE;
- giving a monster with no AI controller its default one;
- moving a stuck or fallen monster;
- spacing monsters around a spawn point;
- finding wave monsters by their spawn key;
- reading a tracked monster only while the game still lists it and it keeps its name;
- telling a dying monster from one that can be executed;
- watching for EVE's death screen, a map load, and EVE leaving the start point.

`mod/StellarCoop/Scripts/nightop/run.lua`, `nightop/waves.lua` and `core/unreal.lua` mark each adapted function. The
death screen lookup is `U.death_screen()` in `core/unreal.lua`, used by the solo run and by the revive in
`session/group.lua`. Stellar Blade Online contains no file from Survival Protocol.

Mother Sphere illustration by timediffer24 (https://x.com/timediffer24), given to this project; not covered by the GPL.
It is `mod/StellarCoop/Assets/MotherSphere.png`, shown in the guide the mod opens at its first run.

## License

[GPL-3.0-or-later](LICENSE) © 2026 Stellar Blade Online contributors

Stellar Blade Online is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later
version.
