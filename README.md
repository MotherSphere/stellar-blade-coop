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
- At a camp phone booth (any full camp, Xion's booths, the Wasteland and Great Desert warp phones), F5 opens the co-op
  line: the menu's session rows, Co-op menu and Hang up, and a sentence that says whether the line is free, open or
  linked with your friend. The booth's own fast travel works as before. The line is not tested in game yet.
- Your friend's EVE appears in your world as a ghost: a display-only copy that moves as she moves, wears her outfit and
  has your friend's Steam name above it. Her ponytail moves as cloth, as in solo (on by default). Her hair colour and
  her attack and skill effects are optional looks, off by default. None of the three looks is tested in game yet.
- Session notices show in a feed at the top left of the screen, for example when a friend joins or leaves, when the
  connection is lost or when the two versions do not match. If a guest loses the host's session, their game tries to
  rejoin it for 60 s.
- During a session, Enter opens a text box to chat with your friend. Chat lines show in the same feed and are kept in
  memory only.
- Your friend's card at the top left shows their name with their ping and map, then their HP, shield and Beta. A
  marker over their ghost shows their name and HP, and an arrow at the edge of the screen points to them when they are
  out of view. The card, marker and arrow stay inside the screen at any resolution and menu size.
- Group play, not tested in game yet:
  - as the guest, F7 takes you to the camp nearest the host through the game's own fast travel when the host is on
    another map or more than 150 m away;
  - when one EVE is down, the shared enemies near the other one fight it, and a down EVE gets no kill by standing near
    one; with the experimental revive (off by default), a friend who stands next to the downed EVE for 3 s revives it
    where it fell;
  - the guest's game pauses while a cutscene plays in the host's game;
  - in a shared area only the host's camp rest brings the enemies back, and a notice tells the guest so;
  - the experimental solid partner option (off by default) stops your EVE at your friend's ghost.
- Solo test tools run the whole ghost pipeline on one PC: a network loopback, and a recording with its replay.
  `coop where` compares positions between two PCs.
- The mod never writes your own saves, unlocks or equipment. It adds to the inventory only when you buy in Night
  Operation's shop, on a co-op save. It reads your saves only to make separate co-op copies of them (see
  [docs/saves.md](docs/saves.md)).

The ghost is display only, and items are not shared. The experimental Shared enemies option (co-op menu, Options,
Combat) is on by default and untested in game. It shares common enemies only while both players play a co-op save (see
[docs/usage.md](docs/usage.md#shared-enemies-experimental)). Same place, same spawns and shared bosses build on it. They
are experimental and on by default too, and the host's settings decide them for both games. As guest, the Same place row
of your co-op menu can still turn same place off on your screen. The experimental Shared quests option (Options, Saves)
is off by default and untested in game. While both players play a co-op save, it makes the quest steps that the host and
the guest make together in the guest's game too, through the game's own quest functions (see
[docs/usage.md](docs/usage.md#shared-quests-experimental)).

## Night Operation

This project found Night Operation in the game files: a multiplayer wave-survival mode that Shift Up prototyped and cut
before release. Its recruiter was meant to stand next to Roxanne in Xion's Scrap Market. The plan is to bring the mode
back for friends over Steam, started from the recruiter's Join choice, for up to six players; the Steam link holds two
today. StellarCoop never contacts the cut mode's online services (Shift Up's servers).

`coop nightop start` runs five timed waves of the game's monsters at EVE where she stands, with an 8-minute timer and
a score, on a co-op save. With no Steam session it is a solo run. In a session the host types it, and both games get
the same waves while both screens show one timer and one score; with shared enemies on, each wave monster has one HP
bar and one death in both games. A run that ends in success or time up gives points for a console shop that sells four
of the game's items. None of this has been tested in game yet (see
[docs/night-operation.md](docs/night-operation.md#the-co-op-run)). `coop challenge` runs four short fights on the same
code, one of them against the game's target dummies, and keeps each one's best run in `coop-records.txt`. The
challenges are solo: they need a co-op save and no Steam session, and give no shop points. They have not been tested
in game yet either (see [docs/night-operation.md](docs/night-operation.md#challenges-coop-challenge)). Two research
previews also run only on a co-op save. `coop recruiter` brings back the cut recruiter near Roxanne, and you can talk
to him. `coop no` tests parts of the cut mode in a solo game. Neither preview is a playable mode.

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
| [docs/night-operation.md](docs/night-operation.md) | The cut mode, the plan, the run alone and with a partner, the reward shop, the challenges and the two previews |
| [docs/saves.md](docs/saves.md) | Save safety, backups, Steam Cloud, the co-op saves, recovery |
| [docs/building.md](docs/building.md) | Building from source, tests, the reproducible build, repository layout |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common problems and which logs to send |

## Requirements

- Stellar Blade on Steam (PC), game build 24463856.
- UE4SS v3.0.1 Beta, as packaged in "Stellar Blade UE4SS 1.3".
- Windows, or Linux with Proton.
- Optional: ConsoleEnablerMod (in that UE4SS package) for the `coop` console commands. The keys work without it.
- To play together, both players need the same StellarCoop protocol (12 in this version) and the same game build.

## Disclaimer

StellarCoop is an unofficial fan mod. It is not affiliated with or endorsed by SHIFT UP or Sony Interactive
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

`mod/StellarCoop/Scripts/nightop_run.lua`, `nightop_waves.lua` and `unreal.lua` mark each adapted function. The death
screen lookup is `U.death_screen()` in `unreal.lua`, used by the solo run and by the revive in `group.lua`. StellarCoop
contains no file from Survival Protocol.

## License

[GPL-3.0-or-later](LICENSE) © 2026 StellarCoop contributors

StellarCoop is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later
version.
