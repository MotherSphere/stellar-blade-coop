# Stellar Blade Online

**Two-player online co-op for Stellar Blade on PC, linked through Steam, with a test lobby for matches of up to 8
players.**

<img align="right" width="200" src="mod/StellarCoop/Assets/MotherSphere.png" alt="Mother Sphere, illustration by timediffer24">

Each player sees the other's EVE in their own world. Stellar Blade Online is a UE4SS mod made of Lua scripts and a
native DLL. The link between the two games goes through the Steam client that the game already runs, so the mod needs
no other program and no server of its own. It was called StellarCoop until October 2026: the mod's folder, its DLL, its
`[StellarCoop]` log tags and its release zip keep that name, and its console commands still start with `coop`.

[![License: SBO License 1.0](https://img.shields.io/badge/License-SBO%20License%201.0-blue.svg)](LICENSE)
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

Close the game before you copy, change or delete any mod file. The mod runs on game build 26123051, which Steam
installed on 2026-11-05; version 0.8.0 and older need build 24463856 (see [Status](#status)). [INSTALL.md](INSTALL.md)
has the full guide.

| Setup | Notes | Guide |
| --- | --- | --- |
| Windows | The three steps above. If Windows Defender quarantines `StellarCoop.dll`, `UE4SS.log` says `Native part not loaded` and the keys do not work. | [Install](INSTALL.md#install), [Windows Defender and SmartScreen](INSTALL.md#windows-defender-and-smartscreen) |
| Linux with Proton, Steam Deck | The same zip. If UE4SS never starts, set the game's Steam launch options to `WINEDLLOVERRIDES="dwmapi=n,b" %command%`. | [Linux and Steam Deck](INSTALL.md#linux-and-steam-deck) |
| From source, on Linux | `python3 tools/install.py [--game <Stellar Blade folder>]` runs the tests, builds the DLL with clang-cl and copies the mod. It backs up the files it replaces into `~/StellarCoop-install-backups`. | [Building from source](docs/dev/building.md) |

## Status

Stellar Blade Online is an experimental beta. This version runs on Stellar Blade's Steam build 26123051 only, which
Steam installed on 2026-11-05. Versions up to 0.8.0 run on build 24463856 only, which Steam no longer serves. On any
other build, `coop status` shows `engine=off reason=build stamp ...` (or `reason=code bytes differ`), and the ghost, the
co-op saves and every other feature that reads the game's memory stay off until a release supports it. Setting Steam's
automatic updates to Wait until I launch the game stops background updates, but Steam still installs a waiting update
when the game starts ([INSTALL.md: Update](INSTALL.md#update)).

Two-PC co-op was first played on 2026-10-17, between a Linux PC with Proton and a Windows PC.
[Features and test status](docs/features.md#status) lists every later test and what has not been tested between two
PCs yet. The SBO lobby has run on one PC only, and no match lobby has held two players in game yet. Leave and the
return to Xion have not run in game, nor has the restore at the title after a failed return. In the lobby EVE wears
Stellar Blade's `Preset_Eve_Max` build, and only that return or restore gives the co-op save its own skills and
equipment back ([SBO lobby: Leaving](docs/online/lobby.md#leaving)).

This version uses link protocol 29 and does not link with 0.11.0 or older, so every player has to update. Every on/off
setting is now on by default, the experimental ones included; most of them have not been tested in game
([Settings](docs/players/settings.md#coop-settingstxt)).

## What it does

- F5 opens the co-op menu. Its first row, Host a session, opens the Create a session screen: pick who can join, the
  players (2 to 4, you included) and the session rules, then Start hosts a Steam lobby. Public, the default, lists the
  online session in Find a session for every player of your version. Friends only opens it to your Steam friends,
  Invitation to a Steam invite or a 7-character join code, Private to nobody. Find a session lists the online sessions
  you can join. See [Playing with a friend](docs/players/playing-with-a-friend.md).
- Your friend's EVE appears in your world as a ghost: a display-only copy that moves as she moves, wears her outfit and
  has your friend's Steam name above it. Items are not shared, except the consumables sent with `coop gift`. See
  [Ghost](docs/online/partner.md).
- Your friend's card at the top left shows their ping, map, HP, shield and Beta. During a session, Enter opens a chat
  box. See [Interface](docs/players/interface.md#partner-hud).
- The SBO lobby (a test) is a waiting room in Xion's training room for matches of up to 8 players. On a co-op save,
  talk to the recruiter near Roxanne and choose Join. Its menu searches for a public match of a mode, hosts a private
  one with a join code, or joins one by code. A countdown starts once 2 players have linked. In a
  [score attack](docs/online/modes/scoreattack.md) match every player then plays the same challenge from her spot.
  The host's game ranks the scores (untested in game). The free-for-all is not built yet, so its round's start takes
  nobody to an arena. `coop pvp` tests PvP damage between two linked friends. See
  [SBO lobby and matches](docs/online/lobby.md).
- Shared enemies (experimental, on by default) give each common enemy one HP bar and one death in both games, while
  both players play a co-op save. Same place, same spawns and shared bosses build on them, and the host's settings
  apply to both games. See [Shared enemies](docs/fight/enemies.md).
- The shared world (experimental, on by default, not tested in game yet) makes a door, lever, switch, crane, lift or
  shortcut that one player works change in the other's game too, while both play a co-op save. Chests, supply boxes
  and other loot stay each player's own. See [Shared world](docs/world/objects.md).
- Story together (experimental, on by default, not tested in game yet) plays the host's story scenes in the guest's
  game too, with his choices, QTE results and skips, while both play a co-op save. See
  [Story together](docs/story/together.md).
- Co-op saves (`StellarBladeCoop00.sav` to `04.sav`) are copies of your own saves that the mod makes on the title
  screen. Night Operation, the challenges, shared enemies, shared quests, the shared world and story together run on
  them only. Nothing goes back to your own saves unless you export it. See
  [Co-op saves](docs/players/playing-with-a-friend.md#co-op-saves).
- Group play adds the friend's revive and shared quests (both experimental and on by default), a pause while a
  cutscene plays in the host's game and travel to where the host stands (F7, not tested in game yet). On the death
  screen F7 takes you back to a living friend. See [Playing with a friend](docs/players/playing-with-a-friend.md).
- In Doro races you record a track with F9 checkpoints, then race it alone or against your friend, each racer drawn
  as a Doro. See [Doro races](docs/online/modes/race.md).
- The bike (not tested in game yet): F3, D-pad Right held 1 s or `coop bike` puts EVE on a motorbike from the game's
  files, on any save. Your friend's ghost of you rides it too. See [The bike](docs/vehicles/bike.md).
- Night Operation is a multiplayer wave-survival mode that Shift Up cut before release. `coop nightop` runs five timed
  waves alone or for both players, and the points buy items in a reward shop. `coop challenge` runs five short fights
  on the same code. See [Night Operation](docs/online/modes/nightop.md).
- The mod brings back content that was cut from the game, or shipped switched off, and is still in its files: a viewer
  for Leviathan and other cut models, the cut Lion (`coop lion`), the Gardener and the Tendril to fight, cut hairs and
  suits (`coop wear`), emotes, the developer flight and slow motion, the cut glide, cut scenes and subtitles, the Load
  Shortcut saves and the developer menu. See [Cut enemies](docs/fight/bosses.md), [EVE's cut moves](docs/eve/eve.md),
  [Cut scenes](docs/story/scenes.md) and [Cut menus and the mailbox](docs/cutmenus/menus.md).
- `coop mxiii` (experimental) travels to a camp in Matrix XIII, an area cut before release. It needs the zMXIII_P
  test pak, which does not come with the mod. See [Matrix XIII](docs/world/matrix13.md).
- Lily's signal adds two quests of the mod's own near the end of the story. The second leads through Matrix XIII and
  needs the same test pak. See [Lily's signal](docs/world/lily-signal.md).
- Solo test tools run the whole ghost pipeline on one PC: a network loopback, and a recording with its replay. See
  [Keys and commands](docs/usage.md#solo-testing-loopback-record-replay).

[Features and test status](docs/features.md) gives the test status of the co-op, Night Operation and cut-content
features; Matrix XIII and Lily's signal have their own pages.

## Requirements

| Requirement | Details |
| --- | --- |
| Game | Stellar Blade on Steam (PC), game build 26123051. [INSTALL.md: Update](INSTALL.md#update) says how to stop Steam from updating the game in the background. |
| UE4SS | v3.0.1 Beta, as packaged in "Stellar Blade UE4SS 1.3". |
| System | Windows, or Linux with Proton (Steam Deck included). |
| Console | Optional: ConsoleEnablerMod (in that UE4SS package) for the `coop` console commands. The keys work without it. |
| Playing together | The same game build and the same link protocol: 29 in this version, which does not link with 0.11.0 (protocol 20) or older versions. |

## Documentation

| Document | Purpose |
| --- | --- |
| [Install](INSTALL.md) | Install, update and uninstall on Windows, Linux and Steam Deck |
| [Playing with a friend](docs/players/playing-with-a-friend.md) | Hosting, joining, join codes and the co-op saves |
| [SBO lobby and matches](docs/online/lobby.md) | The recruiter's Join, the lobby menu, match lobbies of up to 8 players, the hall lobbies, the PvP test |
| [Keys and commands](docs/usage.md) | Every key and `coop` console command, and the F6 and `coop status` lines |
| [Features and test status](docs/features.md) | What the features do and when each was tested |
| [Troubleshooting](docs/players/troubleshooting.md) | Common problems and which logs to send |
| [Building](docs/dev/building.md) | Building from source: the toolchain, `tools/install.py` and releases |
| [How it works](docs/README.md#how-stellar-blade-online-works) | The internals pages, for anyone who reads the code |

[The documentation index](docs/README.md) lists every page, Night Operation and the cut content included.

## Disclaimer

Stellar Blade Online is an unofficial fan mod. It is not affiliated with or endorsed by Shift Up or Sony Interactive
Entertainment. Stellar Blade and its assets belong to their owners. This repository contains no game files; the mod
runs on your own copy of the game.

## Credits

Night Operation's run (`coop nightop`), the challenges (`coop challenge`, which run on the same code) and the friend's
revive adapt code from [Survival Protocol](https://www.nexusmods.com/stellarblade/mods/4009) by SchizoEffective (Nexus
Mods, Stellar Blade mod 4009). The author gave permission, and the code is distributed here under the SBO License (see
[NOTICE](NOTICE)). The challenge list follows Survival Protocol's graded stages: five difficulty stages picked from a
list before a fight. [Night Operation: Credits](docs/online/modes/nightop.md#credits) lists the adapted parts and the files
that mark them.

The bike's riding model and its lean adapt code from [Eve On Wheels](https://www.nexusmods.com/stellarblade/mods/4165)
by dCharisma1 (Nexus Mods, Stellar Blade mod 4165). With his written consent, the code is distributed here under the
SBO License (see [NOTICE](NOTICE)). No asset, sound or animation of Eve On Wheels ships with the mod.

The bike's riding rig (`bike_pose=rig`) adapts the puppet ride of Eve Hoverbike by kwisatz (GitHub sarojratul). With
his written permission, the code is distributed here under the SBO License (see [NOTICE](NOTICE)). No file of Eve
Hoverbike ships with the mod.

Mother Sphere illustration by timediffer24 (https://x.com/timediffer24), given to this project; not covered by the SBO
License. It is `mod/StellarCoop/Assets/MotherSphere.png`, shown in the guide the mod opens at its first run. The release
zip does not contain it.

## License

[SBO License 1.0 or later](LICENSE) © 2026 MotherSphere and the Stellar Blade Online contributors

Stellar Blade Online is free to use, study, change and share under the SBO License, version 1.0 or any later version
that MotherSphere publishes. GPL-3.0 gives these freedoms too. The SBO License gives them to everyone except the
parties it excludes, which its Appendix A and [EXCLUDED-PARTIES.md](EXCLUDED-PARTIES.md) list (AyakaMods in version
1.0). It adds rules of its own: only MotherSphere may sell the mod, running it as a server for other people needs
MotherSphere's written permission, a modified version that you release needs a name of its own, and if other people
play with your modified version over a network, you offer them its source code. Hosting or joining a game while you
play is not running a server. Versions up to 0.9.0 were released under GPL-3.0-or-later and stay under it.
[NOTICE](NOTICE) holds the credits and lists the parts under other terms.
