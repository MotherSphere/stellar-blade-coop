# Stellar Blade Online

Stellar Blade Online is an online co-op mod for Stellar Blade on PC. Two players link their games over Steam, and each
one sees the other's EVE in their own world. It was called StellarCoop until October 2026: the mod's folder, its DLL,
its `coop` console commands and this repository keep that name.

Status: v0.7.0-beta.1, an experimental beta. It runs on Stellar Blade's Steam build 24463856 only. Two-PC co-op was
first played on 2026-10-17, one PC on Linux with Proton and one on Windows, between Belgium and Brazil at about 240 ms
ping. On 2026-10-21 two players on 0.4.0 played on the automatic co-op saves with shared enemies and same place (each
enemy in the same spot on both screens). No later version has been played on two PCs, so nothing added since 0.4 has
been tested between two PCs: shared quests, the friend's revive, the cutscene wait, kills that count only for a player
who took part, Night Operation's run, levels, revive and challenges, Doro races, the co-op line at camp phone booths,
the .pak mod list and CNS outfits over the link, `coop gift` and the pose rate that adapts to Steam's queue. On one PC,
the Leviathan viewer and its free camera ran on 2026-10-22, the Lion was fought on 2026-10-24, the first-launch guide
opened, and on 2026-10-27 the co-op saves loaded and `coop nightop shop` opened its shop screen. 0.6.0-beta.1 to beta.3
use link protocol 13. 0.7.0-beta.1 uses protocol 14 and does not link with them.

Stellar Blade Online is a UE4SS mod made of Lua scripts and a native DLL. The link between the two games goes through
the Steam client that the game already runs, so the mod needs no other program and no server of its own.

## Features

- F5 opens the co-op menu. Its first row hosts a session: by default a friends-only one, with the Steam invite dialog.
  Options can limit the session to invited friends, or open it to anyone who has its 7-character join code, with no
  dialog. A player who is not the host's Steam friend waits until the host accepts them. The invited friend joins once
  their save has loaded, even if Steam had to start their game. The menu also invites, joins, leaves and changes the
  settings. F6 shows the status and F8 leaves the session. On an XInput controller (an Xbox controller, the Steam Deck,
  or any controller under Steam Input), View held for 1 s opens the menu, and the mouse works in it too.
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
  - as the guest, F7 is meant to take you to the camp nearest the host through the game's own fast travel when the
    host is on another map or more than 150 m away. It stays off until the follow has been tested in game. The game's
    fast travel does not check whether your save has activated a camp, so the mod reads the activated camps itself;
    `coop travel probe` and `coop mxiii leave` already use that read;
  - when one EVE is down, the shared enemies near the other one fight it, and a down EVE gets no kill by standing near
    one; with the experimental revive (off by default), a friend who stands next to the downed EVE for 3 s revives it
    where it fell;
  - the guest's game pauses while a cutscene plays in the host's game;
  - in a shared area only the host's camp rest brings the enemies back, and a notice tells the guest so;
  - the experimental solid partner option (off by default) stops your EVE at your friend's ghost.
- Doro races: record a track by setting checkpoints with F9, then race it alone against the clock or against your
  friend, each racer drawn as a Doro (Dororong). The race has a countdown, a timer, checkpoint markers and a ranking.
  It gives no reward or achievement and writes nothing to a save. Doro races are not tested in game yet (see
  [docs/usage.md](docs/usage.md#doro-races)).
- `coop leviathan` shows Leviathan, a Naytiba cut from the game whose models and animations are still in its files, as
  a display-only model in front of EVE, with a free camera for filming. `coop gardener` and `coop tendril` do the same
  for two more cut Naytibas, the Gardener and the Tendril (see
  [docs/usage.md](docs/usage.md#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril)). In the viewer none
  of them can be fought: the game has no entry for them in its character table (`coop gardener fight` and
  `coop tendril fight`, below, add the Gardener's and the Tendril's). `coop mann`, `coop nier`, `coop orcal` and
  `coop enya`
  show the early Mann model, the NieR collaboration's three cut machines and prototype statues of Orcal and Enya the
  same way.
- `coop lion` spawns the Lion, a boss cut from the game, as a real enemy to fight on a co-op save. The game's files keep
  its model, animations and attacks but no table row, so the mod adds the 222 rows it needs to the game's tables in
  memory. `coop lion intro` plays its entrance first. It writes nothing to a save, and only your game has it (see
  [docs/usage.md](docs/usage.md#cut-boss-coop-lion)).
- `coop gardener fight` spawns the Gardener the same way: a cut artillery Naytiba about 20 m tall that never walks and
  shells EVE from its mouth. The mod adds the 13 rows it lacks to the game's tables in memory. It is not tested in game
  yet (see [docs/usage.md](docs/usage.md#cut-enemy-coop-gardener-fight)).
- `coop tendril fight` spawns the Tendril the same way, a cut Naytiba that strikes with four chains on its head. The
  game has no skill presentations for its animations either, so the mod builds them in memory from its own clips, and
  adds the 107 rows it lacks. It is not tested in game yet (see
  [docs/usage.md](docs/usage.md#cut-enemy-coop-tendril-fight)).
- `coop wear` puts EVE in two cut hairs (mechanical cat ears and rabbit ears) and four cut suits, Gothic Rose among
  them, by changing the meshes drawn. Your equipment and saves stay as they are, and your friend's ghost of you shows
  the look too (see [docs/usage.md](docs/usage.md#cut-hairs-and-suits-coop-wear)).
- `coop scene` plays two scenes cut from the game through its own cutscene player, each at its place in the world:
  Emil's farewell from an ending of the first DLC and Orcal's monologue from the 2022 trailer. It writes nothing to a
  save and has not been tried in game yet (see [docs/usage.md](docs/usage.md#cut-scenes-coop-scene)).
- `coop lines` shows the subtitles of four scenes cut before they were voiced in the chat's feed, timed as the game's
  sequences give them: the first meeting with Adam, Quest_Sub_015 with Mann and Orcal's last message, Quinn and Sky
  Hall. The text comes from your game, which has most of them in English and Korean only, so other languages show the
  Korean. `coop lines enya` plays seven voice takes of Enya and Su that the game never uses. Neither has been tried in
  game yet (see [docs/usage.md](docs/usage.md#cut-scene-lines-coop-lines)).
- `coop fly` and `coop slowmo` switch on the developer flight (a third press of the space bar in the air, or R2 held)
  and slow motion (R1) that the game ships turned off, on a co-op save. The flight in this form has not been tried in
  game yet (see [docs/usage.md](docs/usage.md#debug-flight-and-slow-motion-coop-fly-and-coop-slowmo)).
- `coop glide` brings back EVE's cut glide: with Jump held in the air, she falls at a tenth of the normal gravity, on a
  co-op save. It has not been tried in game yet (see [docs/usage.md](docs/usage.md#cut-glide-coop-glide)).
- `coop chainspin` asks for EVE's cut Tachy Mode ChainSpin once, while she is in Tachy Mode: a spin of four hits whose
  last one stuns, with no button and no wing animation. `coop devmenu` runs the 20 rows of the game's developer menu
  that still work (no damage, speed, attack, gauges, enemy rows), and `coop devinfo` opens its quest debugger or
  player info panel. These test commands have not been tried in game yet (see
  [docs/usage.md](docs/usage.md#cut-tachy-skill-coop-chainspin) and
  [docs/usage.md](docs/usage.md#developer-menu-coop-devmenu-and-coop-devinfo)).
- `coop emote <name>` plays one of EVE's clips through the game's own animation call: 31 photo-mode poses held until
  she moves (grouped under the categories of the game's cut Social Action menu), two waves, and six clips of hers made
  for two enemies with no character in the game files: the Chariot, which was cut (its struggle and her takedown on
  it), and Kali, possibly an early name of a shipped enemy (her takedown on Kali and Kali's grab). It has not been
  tried in game yet (see [docs/usage.md](docs/usage.md#emotes-coop-emote)).
- `coop shortcut` lists the 15 developer saves of the cut Load Shortcut menu, read from the game's files: the map and
  camp each one starts at. `coop shortcut load` writes one as co-op slot 5 for Load Game, without its achievement
  list. It is off unless `shortcut_load=on`, since what is left of the developer's progress can still unlock Steam
  achievements. Neither has been tried in game yet (see
  [docs/usage.md](docs/usage.md#cut-load-shortcut-saves-coop-shortcut)).
- At its first run the mod opens a guide of nine pages, with art of Mother Sphere by timediffer24. The Guide row of the
  co-op menu and `coop guide` open it again (see [docs/usage.md](docs/usage.md#guide)).
- Each player's .pak mods are named over the link, and a notice says which ones the other player lacks. A friend's CNS
  outfit shows on your ghost of them when your own CNS packs declare its files (see
  [docs/usage.md](docs/usage.md#mods-and-cns-outfits)).
- If `UE4SS-settings.ini` has `HookBeginPlay` or `bUseUObjectArrayCache` on, a notice says so: the first can crash the
  game when EVE lets go of a movable crate (see [docs/troubleshooting.md](docs/troubleshooting.md)).
- Solo test tools run the whole ghost pipeline on one PC: a network loopback, and a recording with its replay.
  `coop where` compares positions between two PCs.
- The mod never writes your unlocks or equipment, and writes your own saves only when you export a co-op save over one
  of them (`coop saves export`, after a backup). It changes the inventory only when you buy in Night Operation's shop
  or send and take a `coop gift`, on a co-op save. It reads your saves to make separate co-op copies of them (see
  [docs/saves.md](docs/saves.md)).

The ghost is display only, and items are not shared, except the consumables sent with `coop gift`. The experimental
Shared enemies option (co-op menu, Options, Combat) is on by default and untested in game. It shares common enemies only
while both players play a co-op save (see [docs/usage.md](docs/usage.md#shared-enemies-experimental)). Same place, same
spawns and shared bosses build on it. They are experimental and on by default too, and the host's settings decide them
for both games. As guest, the Same place row of your co-op menu can still turn same place off on your screen. The
experimental Shared quests option (Options, Saves) is off by default and untested in game. While both players play a
co-op save, it makes the quest steps that the host and the guest make together in the guest's game too, through the
game's own quest functions (see [docs/usage.md](docs/usage.md#shared-quests-experimental)).

## Night Operation

This project found Night Operation in the game files: a multiplayer wave-survival mode that Shift Up prototyped and cut
before release. Its recruiter was meant to stand next to Roxanne in Xion's Scrap Market. The plan is to bring the mode
back for friends over Steam, started from the recruiter's Join choice, for up to six players; the Steam link holds two
today. The mod never contacts the cut mode's online services (Shift Up's servers).

`coop nightop start` runs five timed waves of the game's monsters at EVE where she stands, with an 8-minute timer and
a score, on a co-op save. `coop nightop start easy`, `hard` or `nightmare` changes the number of monsters (15 to 40 in
all, 20 at normal), the time limit and the shop points. With no Steam session it is a solo run. In a session the host
types it, at his level, and both games get the same waves while both screens show one timer and one score; with
shared enemies on, each wave monster has one HP bar and one death in both games. With the experimental revive on, a
dead EVE in such a run is down for 30 s: her partner revives her with the interact key, as the cut mode planned, or she
revives herself a few times a run (`coop nightop revive`). A run that ends in success or time up gives points for a
shop of seven items: four of the game's, and three cut items the mod adds back (two stimpacks and the Shock Bolt ammo
for EVE's gun). `coop nightop shop` opens it in the game's own shop screen, with your points shown as the cut Beta
Seed, and on a co-op save Roxanne in Xion offers the run's levels and its supplies among her choices. The shop screen
ran in game on 2026-10-27. One solo run on 2026-10-28 spawned its waves, some monsters inside walls, but tracked none
of them. The fixes for the tracking and for the spawn points are untested, and so are the levels, the revive, the
purchases and Roxanne's choices (see [docs/night-operation.md](docs/night-operation.md#the-co-op-run)). `coop challenge` runs five short fights on the same
code, two of them against the game's target dummies, and keeps each one's best run in `coop-records.txt`. They need a
co-op save and give no shop points. Four are solo. The fifth, the Shooting Range, rebuilds the game's cut shooting
test with its score widget, and the host can start it for both players. They have not been tested in game yet either
(see [docs/night-operation.md](docs/night-operation.md#challenges-coop-challenge)). Two research
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
| [docs/story.md](docs/story.md) | Where the save keeps the story and world state (quests, mission records, zones, doors), the tool that snapshots and diffs it, and the read-only live dump (`coop story`) |
| [docs/building.md](docs/building.md) | Building from source, tests, the reproducible build, repository layout |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common problems and which logs to send |

## Requirements

- Stellar Blade on Steam (PC), game build 24463856. [INSTALL.md: Update](INSTALL.md#update) says how to keep Steam
  from updating the game before the mod supports the new build.
- UE4SS v3.0.1 Beta, as packaged in "Stellar Blade UE4SS 1.3".
- Windows, or Linux with Proton.
- Optional: ConsoleEnablerMod (in that UE4SS package) for the `coop` console commands. The keys work without it.
- To play together, both players need the same mod protocol (14 in this version) and the same game build.

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
