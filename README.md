# Stellar Blade Online

Stellar Blade Online is an online co-op mod for Stellar Blade on PC. Two players link their games over Steam, and each
one sees the other's EVE in their own world. It was called StellarCoop until October 2026: the mod's folder, its DLL,
its `coop` console commands and this repository keep that name.

Stellar Blade Online is a UE4SS mod made of Lua scripts and a native DLL. The link between the two games goes through
the Steam client that the game already runs, so the mod needs no other program and no server of its own.

## Install

1. Install UE4SS for Stellar Blade ("Stellar Blade UE4SS 1.3").
2. Download `StellarCoop-<version>.zip` from the
   [Releases](https://github.com/MotherSphere/stellar-blade-coop/releases) page, unzip it, and copy the `StellarCoop`
   folder into `SB/Binaries/Win64/ue4ss/Mods/` in the game folder.
3. Start the game, load a save and press F6. The screen shows `Co-op: not in a session.`

Close the game before you copy, change or delete any mod file. [INSTALL.md](INSTALL.md) has the full guide.

## Requirements

- Stellar Blade on Steam (PC), game build 24463856. [INSTALL.md: Update](INSTALL.md#update) says how to keep Steam
  from updating the game before the mod supports the new build.
- UE4SS v3.0.1 Beta, as packaged in "Stellar Blade UE4SS 1.3".
- Windows, or Linux with Proton.
- Optional: ConsoleEnablerMod (in that UE4SS package) for the `coop` console commands. The keys work without it.
- To play together, both players need the same mod protocol (19 in this version) and the same game build.

## Documentation

| Page | What it covers |
| --- | --- |
| [INSTALL.md](INSTALL.md) | Install, update, check the files, co-op saves, uninstall, which logs to send |
| [docs/usage.md](docs/usage.md) | Keys, the co-op menu, the chat, the partner HUD, every `coop` command, `coop-settings.txt`, looks, notices, status lines, files |
| [docs/how-it-works.md](docs/how-it-works.md) | The Steam link, the ghost pipeline, safety design, loopback and replay |
| [docs/night-operation.md](docs/night-operation.md) | The cut mode, the plan, the run alone and with a partner, the reward shop, the challenges and the two previews |
| [docs/saves.md](docs/saves.md) | Save safety, backups, Steam Cloud, the co-op saves, recovery |
| [docs/story.md](docs/story.md) | Where the save keeps the story and world state (quests, mission records, zones, doors), the tool that snapshots and diffs it, and the read-only live dump (`coop story`) |
| [docs/building.md](docs/building.md) | Building from source, tests, the reproducible build, repository layout |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common problems and which logs to send |

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
