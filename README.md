# Stellar Blade Online

**Two-player online co-op for Stellar Blade on PC, linked through Steam.**

<img align="right" width="200" src="mod/StellarCoop/Assets/MotherSphere.png" alt="Mother Sphere, illustration by timediffer24">

Each player sees the other's EVE in their own world. Stellar Blade Online is a UE4SS mod made of Lua scripts and a
native DLL. The link between the two games goes through the Steam client that the game already runs, so the mod needs
no other program and no server of its own. It was called StellarCoop until October 2026: the mod's folder, its DLL and
its `coop` console commands keep that name.

[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/MotherSphere/stellar-blade-coop?include_prereleases&label=release)](https://github.com/MotherSphere/stellar-blade-coop/releases)
[![Nexus Mods: Stellar Blade Online](https://img.shields.io/badge/Nexus%20Mods-Stellar%20Blade%20Online-d98f40)](https://www.nexusmods.com/stellarblade/mods/4011)
[![Game: Stellar Blade on Steam (PC)](https://img.shields.io/badge/game-Stellar%20Blade%20%28Steam%2C%20PC%29-informational)](https://store.steampowered.com/app/3489700/)
[![Platforms: Windows, Linux with Proton](https://img.shields.io/badge/platforms-windows%20%7C%20linux%20%28proton%29-lightgrey)](#requirements)

---

## Install

1. Install UE4SS for Stellar Blade ("Stellar Blade UE4SS 1.3").
2. Download `StellarCoop-<version>.zip` from the
   [Releases](https://github.com/MotherSphere/stellar-blade-coop/releases) page, unzip it, and copy the `StellarCoop`
   folder into `SB/Binaries/Win64/ue4ss/Mods/` in the game folder.
3. Start the game. On the title screen the mod opens its guide, then asks whether to play on co-op saves. Choose
   Decide later until you have backed up your saves. Load a save and press F6. The screen shows
   `Co-op: not in a session.`

Close the game before you copy, change or delete any mod file. Version 0.8.0 does not run on game build 26123051, which
Steam installed on 2026-11-05 (see [Status](#status)). [INSTALL.md](INSTALL.md) has the full guide.

| Setup | Notes | Guide |
| --- | --- | --- |
| Windows | The three steps above. If Windows Defender quarantines `StellarCoop.dll`, `UE4SS.log` says `Native part not loaded` and the keys do not work. | [Install](INSTALL.md#install), [Windows Defender and SmartScreen](INSTALL.md#windows-defender-and-smartscreen) |
| Linux with Proton, Steam Deck | The same zip. If UE4SS never starts, set the game's Steam launch options to `WINEDLLOVERRIDES="dwmapi=n,b" %command%`. | [Linux and Steam Deck](INSTALL.md#linux-and-steam-deck) |
| From source, on Linux | `python3 tools/install.py [--game <Stellar Blade folder>]` runs the tests, builds the DLL with clang-cl and copies the mod. It backs up the files it replaces into `~/StellarCoop-install-backups`. | [Building from source](docs/building.md) |

## Status

Version 0.8.0 is an experimental beta. It runs on Stellar Blade's Steam build 24463856 only. Steam updated the game to
build 26123051 on 2026-11-05, and 0.8.0 does not support that build. On that build, `coop status` shows
`engine=off reason=build stamp ...` (or `reason=code bytes differ`), and the ghost, the co-op saves and every other
feature that reads the game's memory stay off until a release supports it. Setting Steam's automatic updates to Wait
until I launch the game stops background updates, but Steam still installs a waiting update when the game starts
([INSTALL.md: Update](INSTALL.md#update)).

Two-PC co-op was first played on 2026-10-17, between a Linux PC with Proton and a Windows PC.
[Features and test status](docs/features.md#status) lists every later test and what has not been tested between two
PCs yet.

## What it does

- F5 opens the co-op menu. Its first row, Host a session, creates a Steam lobby for 2 players and opens the Steam
  invite dialog. Options can limit the session to invited friends, or give it a 7-character join code and open no
  dialog. See [Playing with a friend](docs/playing-with-a-friend.md).
- Your friend's EVE appears in your world as a ghost: a display-only copy that moves as she moves, wears her outfit and
  has your friend's Steam name above it. Items are not shared, except the consumables sent with `coop gift`. See
  [Ghost](docs/ghost.md).
- Your friend's card at the top left shows their ping, map, HP, shield and Beta. During a session, Enter opens a chat
  box. See [Interface](docs/interface.md#partner-hud).
- Shared enemies (experimental, on by default) give each common enemy one HP bar and one death in both games, while
  both players play a co-op save. Same place, same spawns and shared bosses build on them, and the host's settings
  apply to both games. See [Shared enemies](docs/shared-enemies.md).
- Co-op saves (`StellarBladeCoop00.sav` to `04.sav`) are copies of your own saves that the mod makes on the title
  screen. Night Operation, the challenges, shared enemies and shared quests run on them only, and nothing goes back to
  your own saves unless you export it. See [Co-op saves](docs/playing-with-a-friend.md#co-op-saves).
- Group play adds the friend's revive and shared quests (both experimental and off by default), a pause while a
  cutscene plays in the host's game, and travel to the camp nearest the host (F7, off in this version). See
  [Playing with a friend](docs/playing-with-a-friend.md).
- In Doro races you record a track with F9 checkpoints, then race it alone or against your friend, each racer drawn
  as a Doro. See [Doro races](docs/doro-races.md).
- Night Operation is a multiplayer wave-survival mode that Shift Up cut before release. `coop nightop` runs five timed
  waves alone or for both players, and the points buy items in a reward shop. `coop challenge` runs five short fights
  on the same code. See [Night Operation](docs/night-operation.md).
- The mod brings back content that was cut from the game, or shipped switched off, and is still in its files: a viewer
  for Leviathan and other cut models, the cut Lion (`coop lion`), the Gardener and the Tendril to fight, cut hairs and
  suits (`coop wear`), emotes, the developer flight and slow motion, the cut glide, cut scenes and subtitles, the Load
  Shortcut saves and the developer menu. See [Cut content](docs/README.md#cut-content).
- `coop mxiii` (experimental) travels to a camp in Matrix XIII, a dungeon cut before release. It needs the zMXIII_P
  test pak, which does not come with the mod. See [Matrix XIII](docs/matrix-xiii.md).
- Lily's signal adds two quests of the mod's own near the end of the story. The second leads through Matrix XIII and
  needs the same test pak. See [Lily's signal](docs/lily-signal.md).
- Solo test tools run the whole ghost pipeline on one PC: a network loopback, and a recording with its replay. See
  [Keys and commands](docs/usage.md#solo-testing-loopback-record-replay).

[Features and test status](docs/features.md) gives the test status of the co-op, Night Operation and cut-content
features; Matrix XIII and Lily's signal have their own pages.

## Requirements

| Requirement | Details |
| --- | --- |
| Game | Stellar Blade on Steam (PC), game build 24463856. [INSTALL.md: Update](INSTALL.md#update) says how to stop Steam from updating the game in the background. |
| UE4SS | v3.0.1 Beta, as packaged in "Stellar Blade UE4SS 1.3". |
| System | Windows, or Linux with Proton (Steam Deck included). |
| Console | Optional: ConsoleEnablerMod (in that UE4SS package) for the `coop` console commands. The keys work without it. |
| Playing together | The same game build and the same link protocol: 19 in 0.8.0, which does not link with 0.7.5 (protocol 18) or older versions. |

## Documentation

| Document | Purpose |
| --- | --- |
| [Install](INSTALL.md) | Install, update and uninstall on Windows, Linux and Steam Deck |
| [Playing with a friend](docs/playing-with-a-friend.md) | Hosting, joining, join codes and the co-op saves |
| [Keys and commands](docs/usage.md) | Every key and `coop` console command, and the F6 and `coop status` lines |
| [Features and test status](docs/features.md) | What the features do and when each was tested |
| [Troubleshooting](docs/troubleshooting.md) | Common problems and which logs to send |
| [Building](docs/building.md) | Building from source: the toolchain, `tools/install.py` and releases |
| [How it works](docs/how-it-works.md) | The internals pages, for anyone who reads the code |

[The documentation index](docs/README.md) lists every page, Night Operation and the cut content included.

## Disclaimer

Stellar Blade Online is an unofficial fan mod. It is not affiliated with or endorsed by Shift Up or Sony Interactive
Entertainment. Stellar Blade and its assets belong to their owners. This repository contains no game files; the mod
runs on your own copy of the game.

## Credits

Night Operation's run (`coop nightop`), the challenges (`coop challenge`, which run on the same code) and the friend's
revive adapt code from [Survival Protocol](https://www.nexusmods.com/stellarblade/mods/4009) by SchizoEffective (Nexus
Mods, Stellar Blade mod 4009). The author gave permission, and the code is distributed here under GPL-3.0-or-later. The
challenge list follows Survival Protocol's graded stages: five difficulty stages picked from a list before a fight.
[Night Operation: Credits](docs/night-operation.md#credits) lists the adapted parts and the files that mark them.

Mother Sphere illustration by timediffer24 (https://x.com/timediffer24), given to this project; not covered by the GPL.
It is `mod/StellarCoop/Assets/MotherSphere.png`, shown in the guide the mod opens at its first run.

## License

[GPL-3.0-or-later](LICENSE) © 2026 Stellar Blade Online contributors

Stellar Blade Online is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later
version.
