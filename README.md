# StellarCoop

StellarCoop is a co-op mod for Stellar Blade on PC. Two players link their games over Steam, and each one sees the
other's EVE in their own world.

Status: v0.1.1, an experimental pre-release. It runs on Stellar Blade's Steam build 24463856 only. The ghost co-op was
first played between two PCs on 2026-10-17, one on Linux with Proton and one on Windows, between Belgium and Brazil at
about 240 ms ping. Longer sessions, level changes and the optional looks have not been tested between two PCs. The
co-op menu, the chat and the partner HUD have not been tested in game yet.

StellarCoop is a UE4SS mod made of Lua scripts and a native DLL. The link between the two games goes through the Steam
client that the game already runs, so the mod needs no other program and no server of its own.

## Features

- F5 opens the co-op menu. Its first row hosts a session: by default a friends-only one, with the Steam invite dialog.
  Options can limit the session to invited friends, or open it to anyone who has its 7-character join code, with no
  dialog. A player who is not the host's Steam friend waits until the host accepts them. The invited friend joins once
  their save has loaded, even if Steam had to start their game. The menu also invites, joins, leaves and changes the
  settings. F6 shows the status and F8 leaves the session.
- Your friend's EVE appears in your world as a ghost: a display-only copy that moves as she moves, wears her outfit and
  has your friend's Steam name above it. Three optional looks are off by default and untested in game: her ponytail as
  cloth, her hair colour, and her attack and skill effects.
- Session notices show in a feed at the top left of the screen, for example when a friend joins or leaves, when the
  connection is lost or when the two versions do not match. If a guest loses the host's session, their game tries to
  rejoin it for 60 s.
- During a session, Enter opens a text box to chat with your friend. Chat lines show in the same feed and are kept in
  memory only.
- Your friend's card at the top left shows their name with their ping and map, then their HP, shield and Beta. A
  marker over their ghost shows their name and HP, and an arrow at the edge of the screen points to them when they are
  out of view. The card, marker and arrow stay inside the screen at any resolution and menu size.
- Solo test tools run the whole ghost pipeline on one PC: a network loopback, and a recording with its replay.
  `coop where` compares positions between two PCs.
- The mod never writes your own saves, the inventory, unlocks or equipment. It reads your saves only to make
  separate co-op copies of them (see [docs/saves.md](docs/saves.md)).

The ghost is display only. Items and progress are not shared. The experimental Shared enemies option (co-op menu,
Options, Combat) is on by default and untested in game. It shares common enemies only while both players play a co-op
save (see [docs/usage.md](docs/usage.md#shared-enemies-experimental)).

## Night Operation

This project found Night Operation in the game files: a multiplayer wave-survival mode that Shift Up prototyped and cut
before release. Its recruiter was meant to stand next to Roxanne in Xion's Scrap Market. The plan is to bring the mode
back for friends over Steam, with identical waves, kills in sync, and a shared timer and score, for two players first
and then up to six. StellarCoop never contacts the cut mode's online services (Shift Up's servers).

Two research previews run only on a co-op save. `coop recruiter` brings back the cut recruiter near Roxanne,
and you can talk to him. `coop no` tests parts of the cut mode in a solo game. Neither is a playable mode. See
[docs/night-operation.md](docs/night-operation.md).

## Install

1. Install UE4SS for Stellar Blade ("Stellar Blade UE4SS 1.3").
2. Download `StellarCoop-<version>.zip` from the
   [Releases](https://github.com/MotherSphere/stellar-blade-coop/releases) page, unzip it, and copy the `StellarCoop`
   folder into `SB/Binaries/Win64/ue4ss/Mods/` in the game folder.
3. Start the game, load a save and press F6. The screen shows `Co-op: not in a session.`

Close the game before you copy, change or delete any mod file. [INSTALL.md](INSTALL.md) has the full guide.

## Documentation

| Page | What it covers |
| --- | --- |
| [INSTALL.md](INSTALL.md) | Install, update, check the files, co-op saves, uninstall, which logs to send |
| [docs/usage.md](docs/usage.md) | Keys, the co-op menu, the chat, the partner HUD, every `coop` command, `coop-settings.txt`, looks, notices, status lines, files |
| [docs/how-it-works.md](docs/how-it-works.md) | The Steam link, the ghost pipeline, safety design, loopback and replay |
| [docs/night-operation.md](docs/night-operation.md) | The cut mode, the plan, and the two previews |
| [docs/saves.md](docs/saves.md) | Save safety, backups, Steam Cloud, the co-op saves, recovery |
| [docs/building.md](docs/building.md) | Building from source, tests, the reproducible build, repository layout |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common problems and which logs to send |

## Requirements

- Stellar Blade on Steam (PC), game build 24463856.
- UE4SS v3.0.1 Beta, as packaged in "Stellar Blade UE4SS 1.3".
- Windows, or Linux with Proton.
- Optional: ConsoleEnablerMod (in that UE4SS package) for the `coop` console commands. The keys work without it.
- To play together, both players need the same StellarCoop protocol (11 in this version) and the same game build.

## Disclaimer

StellarCoop is an unofficial fan mod. It is not affiliated with or endorsed by SHIFT UP or Sony Interactive
Entertainment. Stellar Blade and its assets belong to their owners. This repository contains no game files; the mod
runs on your own copy of the game.

## License

[GPL-3.0-or-later](LICENSE) © 2026 StellarCoop contributors

StellarCoop is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later
version.
