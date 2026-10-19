# StellarCoop

**Co-op for Stellar Blade on PC: see your friend's EVE in your game, linked over Steam.**

> **Status: v0.1.1, an experimental pre-release.** The ghost co-op works between two PCs: first played on
> 2026-10-17 between Linux with Proton and Windows, Belgium to Brazil, at about 240 ms ping. It runs on Stellar Blade's
> Steam build 24463856 only.

StellarCoop is a UE4SS mod: a few Lua scripts and a native DLL. It needs no other program and no server of its own. The Steam
link goes through the Steam client that the game already runs.

## What it does today

- **A co-op menu.** Press F5, then Enter, to host a friends-only session and invite a friend from the Steam dialog.
  They join by themselves once their save has loaded, even if Steam had to start their game. The menu also leaves,
  invites, joins and changes every setting; F6 gives the status and F8 leaves.
- **A friend's ghost in your world.** A display-only copy of your friend's EVE moves as she moves, wears her outfit and
  carries their Steam name. Optional looks, off by default and not yet tried in game: her ponytail as cloth, her hair
  colour and her attack and skill effects.
- **Session notices** above your EVE: a friend joined or left, connection lost, version mismatch, and more. A guest
  who loses the host's session tries to rejoin it by themselves for 60 s.
- **Solo tools** that run the whole ghost pipeline on one PC: a network loopback, a recording and its replay, and
  `coop where` to compare positions between two PCs.
- **Your saves stay yours.** The mod never reads or writes a save, the inventory, unlocks or equipment.

What it does not do yet: the ghost is visual only. Enemies, kills, items and progress are not shared.

## Night Operation

The game files hold **Night Operation**, a multiplayer wave-survival mode that Shift Up prototyped and cut before
release. Its recruiter was meant to stand next to Roxanne in Xion's Scrap Market. StellarCoop found the mode in the game
files, and the plan is to bring it back with friends over Steam: identical waves, kills in sync, a shared timer and
score, two players first and then up to six. The cut mode's own online services (Shift Up's servers) are never
contacted.

Two research previews let you meet the recruiter and test the mode's pieces today, on a dedicated co-op save slot.
They are not a playable mode yet. See [docs/night-operation.md](docs/night-operation.md).

## Quick install

1. Install UE4SS for Stellar Blade ("Stellar Blade UE4SS 1.3").
2. Download `StellarCoop-<version>.zip` from the
   [Releases](https://github.com/MotherSphere/stellar-blade-coop/releases) page, unzip it, and copy the `StellarCoop`
   folder into `SB/Binaries/Win64/ue4ss/Mods/` in the game folder.
3. Start the game, load a save and press F6. A line above EVE should answer `Co-op: not in a session.`

Close the game before you copy, change or delete any mod file. The full guide, with updates, file checks and the co-op
save slot, is [INSTALL.md](INSTALL.md).

## Documentation

| Page | What it covers |
| --- | --- |
| [INSTALL.md](INSTALL.md) | Install, update, check the files, co-op save slot, uninstall, which logs to send |
| [docs/usage.md](docs/usage.md) | Keys, every `coop` command, `coop-settings.txt`, looks, notices, status lines, files |
| [docs/how-it-works.md](docs/how-it-works.md) | Architecture: the Steam link, the ghost pipeline, safety design, loopback and replay |
| [docs/night-operation.md](docs/night-operation.md) | The cut mode, the plan, and the two previews |
| [docs/saves.md](docs/saves.md) | Save safety, backups, Steam Cloud, the co-op save slot, recovery |
| [docs/building.md](docs/building.md) | Building from source, tests, the reproducible build, repository layout |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common problems and which logs to send |

## Requirements

- Stellar Blade on Steam (PC), game build 24463856.
- UE4SS v3.0.1 Beta, as packaged in "Stellar Blade UE4SS 1.3".
- Windows, or Linux with Proton.
- Optional: ConsoleEnablerMod (in that UE4SS package) for the `coop` console commands. The keys work without it.
- To play together, both players need the same StellarCoop protocol (8 in this version) and the same game build.

## Roadmap

- More sessions between two PCs: longer play, level changes, the optional looks.
- Night Operation with friends over Steam: the recruiter in the Scrap Market, Join starting a Steam friends match,
  identical waves and kills in sync, a shared timer and score, on the co-op save slot.
- Larger groups: two players first, then up to six.

## Disclaimer

StellarCoop is an unofficial fan mod. It is not affiliated with or endorsed by SHIFT UP or Sony Interactive
Entertainment. Stellar Blade and its assets belong to their owners. This repository contains no game files: the mod
uses the game you own.

## License

[GPL-3.0-or-later](LICENSE) © 2026 StellarCoop contributors

StellarCoop is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later
version.
