# Installing Stellar Blade Online

Stellar Blade Online is an experimental online mod for Stellar Blade on PC. Up to 4 players play together in an online
session linked through Steam. A test lobby runs matches of up to 8 players. Its folder, its DLL and its zip keep its
first name, StellarCoop. It runs inside UE4SS. These steps cover Windows and Linux with Proton; a Windows PC and a
Linux PC have played together. The rest of the documentation is in
[docs/](https://github.com/MotherSphere/stellar-blade-coop/tree/main/docs) in the repository.

**Close the game before you copy, change or delete any mod file.**

## Requirements

- Stellar Blade on Steam, game build 26123051. `coop status` reports the build as `build=...` in `UE4SS.log`.
- UE4SS, as packaged in "Stellar Blade UE4SS 1.3" (UE4SS v3.0.1 Beta, git `08a0733`). The first lines of
  `UE4SS.log` show the version, for example `UE4SS - v3.0.1 Beta #0 - Git SHA #08a0733`.
- Optional: ConsoleEnablerMod, which comes with that UE4SS package, for the `coop` console commands. The keys (see
  "Keys and settings") work without it. It needs the line `ConsoleEnablerMod : 1` in `Mods/mods.txt`. SBO's own UE4SS
  package (`--ue4ss` under "Install") includes ConsoleEnablerMod and starts it. In game, `F10` or `~` (tilde) opens
  the console.

## Find the folders

- Game folder: in Steam, right-click Stellar Blade, then Manage, then Browse local files.
- UE4SS folder: `SB/Binaries/Win64/ue4ss/` inside the game folder. It holds `UE4SS.dll`, `UE4SS.log` and `Mods/`.
- Mods folder: `SB/Binaries/Win64/ue4ss/Mods/`.

## Install

1. Close the game.
2. Unzip `StellarCoop-<version>.zip`. You get a folder named `StellarCoop`. Windows "Extract All" may put it one
   level deeper, in `StellarCoop-<version>\StellarCoop\`; in that case, use the inner `StellarCoop` folder.
3. Optional but recommended: check the files (see "Check the files" below).
4. Copy the whole `StellarCoop` folder (the one that holds `enabled.txt`) into the Mods folder. The result must be
   `SB/Binaries/Win64/ue4ss/Mods/StellarCoop/Scripts/main.lua`, with `StellarCoop.dll` and `enabled.txt` next to
   `Scripts/`.
5. Start the game. On the title screen the mod first opens its guide (Esc closes it), then asks whether to play on
   co-op saves (see "Co-op saves" below). Choose Decide later until you have backed up your saves (see "Saves and
   Steam Cloud"). Load a save and press `F6`.
   `Co-op: not in a session.` appears at the top left of the screen (or above EVE, in the first seconds after a load).
   `UE4SS.log` gets the same text in a line that contains `[StellarCoop] OK:`.
   If no line appears, close the game and look in `UE4SS.log` for lines with `[StellarCoop]`. `Native part not loaded`
   means that `StellarCoop.dll` is missing or quarantined (see "Windows Defender and SmartScreen"). The keys do not
   work without it.

UE4SS starts every mod folder that contains an `enabled.txt` file, so you do not need to edit `mods.txt`.

On Linux, you can build and install the mod from the Stellar Blade Online repository instead, with
`python3 tools/install.py`. Add `--game <Stellar Blade folder>` if the game is not in the script's default folder
(`--help` shows it). The script first backs up the files it replaces into `~/StellarCoop-install-backups`.

`python3 tools/install.py --ue4ss` also installs SBO's own UE4SS package in place of the 1.3 package: the official UE4SS
v4.0.0 with SBO's build of `UE4SS.dll`, Stellar Blade Online's settings and the files of your game build. Build that DLL
first with `python3 tools/ue4ss_build.py` (see [docs/dev/building.md](docs/dev/building.md#ue4ssdll)). A build with that
tool does not pass the check yet: its bytes differ from the pinned build
([docs/dev/ue4ss.md](docs/dev/ue4ss.md#ue4ssdll) says why). The script backs up each UE4SS file it replaces or removes
into the same folder. On a game build it has no files for, it writes no UE4SS file. This option is still being tested.
Without it, the script leaves your UE4SS as it is.
[docs/dev/ue4ss.md](docs/dev/ue4ss.md) lists what the package holds.

### Linux and Steam Deck

UE4SS starts through the `dwmapi.dll` next to the game's executable, in `SB/Binaries/Win64/`. Proton can load its own
`dwmapi.dll` instead. UE4SS then never starts, and `ue4ss/UE4SS.log` is never written. If that happens, right-click
Stellar Blade in Steam, then Properties, General, and set Launch options to:

```
WINEDLLOVERRIDES="dwmapi=n,b" %command%
```

`n,b` makes Wine load the game folder's `dwmapi.dll` first, and its own copy only when that one is missing.

### Update

This version runs on game build 26123051 only, which Steam installed on 2026-11-05. Versions up to 0.8.0 run on build
24463856 only. After a game update, `coop status` shows `engine=off reason=build stamp ...` (or `reason=code bytes
differ`), and the ghost, the co-op saves and every other feature that reads the game's memory stay off until a Stellar
Blade Online version supports the new build. To stop Steam from updating the game in the background, right-click Stellar
Blade in your Steam library, then Properties, Updates, and set Automatic updates to Wait until I launch the game (older
Steam clients: Only update this game when I launch it). Steam still installs a waiting update when you start the game,
so check for a new Stellar Blade Online version first. Both players need the same game build.

`CHANGELOG.md` in the zip gives the zip's version and its features and fixes, newest first. Both players must update
together. Two games with different protocols cannot link, and the player who tries to join sees
`Version mismatch: that game runs protocol ..., build ...; yours runs ...`. This version uses protocol 29, for
the shared world, story together, sessions of up to 4 players, the score attack, the travel to the host, the fishing
tournament, Doro races in matches, the ghost's drone, sounds, effects and faces, then spectate, the first-press
finisher and the QTE owner in boss fights. It does not link with 0.11.0 or older (protocol 20).
In a match lobby, the host's game refuses a player on another protocol, and Search never finds a lobby made by
another version.

1. Close the game.
2. From the old `Mods/StellarCoop` folder, copy out what you want to keep: `coop-settings.txt` if you changed a setting,
   by hand or in the menu's Options, `coop-guide.txt` (without it the guide opens again), `coop-records.txt` for your
   best challenge runs, every `coop-night-*.txt` (your Night Operation shop points, which no save holds), every
   `coop-gift-*.txt` (your `coop gift` mailbox: gifts that wait for you, gifts you sent that wait for an answer and
   items on their way back to you, which no save holds either), every `coop-track-*.txt` (your Doro race tracks),
   `coop-tracks.txt` (the names of your tracks that a match lobby may offer), every `coop-bike-<steamid>-*.txt` (where
   your parked bike stands for each save), `coop-blocked.txt` (your block list) and any log you still want to send.
   The zip has no `coop-settings.txt`; when the file is missing, the mod writes the defaults again.
3. Delete the old `StellarCoop` folder, so that no file of the old version remains.
4. Install the new zip with install steps 2 to 4, and put the `coop-*.txt` files from step 2 back into the new folder.
   A file from version 0.2 says `shared_enemies=off`: shared enemies stay off until you turn them on in
   Options > Combat. In a file written by 0.5.0-beta.1 to 0.10.0, the settings that it says are off by default (the
   spawn filter, shared quests, the revive, the solid partner, the Load Shortcut saves, the name tag in photos and the
   status strip) are turned on once at the first load, since every on/off setting is now on by default. The old file
   is kept as `coop-settings.old.txt` until your first change in Options in a later game run writes over it, so copy it
   elsewhere to keep it. Turn a setting off again in Options or in the file (see
   [docs/players/settings.md](docs/players/settings.md#coop-settingstxt)).
5. Do install step 5, with your status key if you changed it.

## Other mods

UE4SS reads its settings from `ue4ss/UE4SS-settings.ini`. The file in the Stellar Blade UE4SS 1.3 package has
`HookBeginPlay = 0` and `bUseUObjectArrayCache = false`. The Custom Nanosuit System (CNS) mod comes with its own
`UE4SS-settings.ini`. Do not copy it over the 1.3 file. With `HookBeginPlay = 1`, the game can crash when EVE lets go
of a movable crate, and `bUseUObjectArrayCache = true` can cause stutter and crashes at startup. If you already copied
it, close the game and set those two lines back to `HookBeginPlay = 0` and `bUseUObjectArrayCache = false`.

When the game starts, the mod reads these two lines. If one of them is on, or missing (UE4SS then uses its default,
which is on), the mod writes a `[StellarCoop] UE4SS-settings.ini:` line to `UE4SS.log` and shows a notice. It never
changes the file.

If the game no longer starts at all after a Stellar Blade update, see
[Troubleshooting: The game does not start at all with UE4SS installed](docs/players/troubleshooting.md#the-game-does-not-start-at-all-with-ue4ss-installed).

## Keys and settings

- `F5` opens the co-op menu. Its first row, Host a session, opens the Create a session screen: pick who can join
  (Public by default, Friends only, Invitation or Private) and the session rules, then select Start. Friends only and
  Invitation open the Steam invite dialog, where you pick your friend. Find a session lists the online sessions you
  can join. While you host, the menu has Invite a friend and Leave the session instead. The arrow keys (or WASD, or
  ZQSD) move, Enter selects and Esc goes back. Within 3 m of a camp phone booth, `F5` opens the co-op line instead, a
  page with the same session rows. See [docs/players/interface.md](docs/players/interface.md#co-op-menu).
- On a controller, hold View for 1 s to open or close the co-op menu. The D-pad or the left stick moves, A selects
  and B goes back. The mouse works in the menu too: move onto a row, left click to select, right click to go back. See
  [docs/players/interface.md](docs/players/interface.md#controller).
- The game's pause menu gets an Online tab after Settings. On the Settings tab, RB (E on the keyboard) closes the pause
  menu and opens the co-op menu. See [docs/players/interface.md](docs/players/interface.md#pause-menu).
- `F6` (status) shows one line on screen and writes it to `UE4SS.log`, for example `Co-op: hosting Alex.`
- `F7`, as the guest on a co-op save, takes you to where the host last stood on solid ground. When the host is on
  another map, the game's fast travel takes you to the camp nearest him first. On the death screen, with `revive=on`,
  it takes you back to a living friend on your map. See
  [docs/players/playing-with-a-friend.md](docs/players/playing-with-a-friend.md#following-the-host).
- `F8` leaves the session. When the host leaves, the guest leaves too.
- `F9` sets a checkpoint while you record a Doro race track. See [docs/online/modes/race.md](docs/online/modes/race.md).
- `F3` puts EVE on the bike or takes her off it, on any save. On a controller, hold D-pad Right for 1 s. See
  [docs/vehicles/bike.md](docs/vehicles/bike.md).
- `F4` brings the NIKKE rifle out or puts it away (gun mode, experimental). On a controller, tap D-pad Right. Without
  the optional `zNGMSpike_P` pak, it only shows the notice `Gun mode: rebuilding`. See
  [docs/fight/gunmode.md](docs/fight/gunmode.md).
- Hold `F2` to open the emote wheel, point at an emote with the mouse, then release `F2` to play it. On a controller,
  hold D-pad Left for 0.3 s, point with the right stick, then release D-pad Left. See
  [docs/players/interface.md](docs/players/interface.md#emote-wheel).
- `Enter`, during a session or in the SBO lobby, opens the chat box. See
  [docs/players/interface.md](docs/players/interface.md#session-chat).
- On a co-op save in Xion, the recruiter near Roxanne in the Scrap Market takes you to the SBO lobby when you choose
  Join: a test lobby for matches of up to 8 players, where `F5` opens the lobby menu. See
  [docs/online/lobby.md](docs/online/lobby.md).

Your friend accepts the invite in Steam, or selects your session in Find a session. If their game is closed when they
accept an invite, Steam starts it. They join once they have loaded a save. Both ghosts then turn on automatically.
Session events (a friend joined or left, connection lost, a rejoin) show for 8 s in the feed at the top left of the
screen and also go to `UE4SS.log`. While the on-screen UI is not up (in the first seconds after a load or a map change,
during your own photo mode, or after an engine error), they show above EVE for 4 s instead.

With Who can join set to Invitation (`who_can_join=invitation`), Start opens the invite dialog too. A notice and the
menu's Copy my code row give a 7-character join code such as `CCS-CBMH`. Each new session gets a new one. Send it to the
other player, who selects Join with a code in their co-op menu and types it. Your Steam friends get in at once, unless
you set Friends join without asking to Off. For a player who is not on your Steam friends list, in any session you host,
the game's popup asks whether to let them in: Accept or Decline. With no answer in 60 s, the player is refused. A
refused player cannot come back to that session. To send out a player you let in, select Remove <name> in the menu, then
select it again within 3 s. Remove also puts that player on your block list, which keeps them out of every game you host
later, after a game restart too, until `coop unblock`. See
[docs/players/playing-with-a-friend.md](docs/players/playing-with-a-friend.md#asking-to-join) and its
[block list](docs/players/playing-with-a-friend.md#block-list) section.

The mod writes `Mods/StellarCoop/coop-settings.txt` the first time the game starts with it. The menu's Options page
changes one line of the file at a time, and keeps the file as it was before its first change since the mod loaded as
`coop-settings.old.txt`. To change a setting by hand, close the game, edit the file, then start the game again:

- `menu_key`, `status_key`, `leave_key`: `F1` to `F12` except `F10` (it opens the console), with at most one of
  `Shift+`, `Ctrl+` or `Alt+` in front, for example `menu_key=Shift+F7`. `host_key` takes the same keys, or `none` (the
  default); a key set there hosts at once, without the menu. `follow_key` (`F7`), `race_key` (`F9`), `bike_key`
  (`F3`), `gun_key` (`F4`) and `emote_key` (`F2`) take the same keys, or `none`. If two actions share one key, all nine
  keys go back to their defaults. A file written before the menu existed has no
  `menu_key` line: the menu then opens on that file's `host_key`, and no key hosts at once.
- `who_can_join`: `public` (the default: any player of your version finds your online session in the session list),
  `friends` (your Steam friends can join from their friends list or Find a session's Friends tab), `invitation` (the
  friends you invite or anyone with your join code) or `closed` (Private in the menu: nobody can join). A player who is
  not your Steam friend waits for your answer. The words `code` and `private` from 0.11 and older read as `invitation`.
  It counts for the next session you host.
- `friends_ask`: `off` (the default: your Steam friends join at once) or `on` (they wait for your answer too), with
  `public` or `invitation`.
- `name_tag`: `on` or `off`, your friend's Steam name above their ghost. While the partner marker shows their name
  (`partner_bar=on`, the default), the name tag is hidden.
- `send_rate`: poses sent to your friend per second, from 10 to 60 (60 by default), at most one per game frame. The
  ghost you see moves at your friend's rate, so both of you need the new value. A file made by an older version that
  still says 20, the old default, is changed to 60 when the mod loads, once; any other value stays.
- `cloth`, `dyes`, `effects`: `on` or `off`, what your friend's ghost shows. All three are on by default. The file
  names them only in a comment, so add a line such as `dyes=off` or `cloth=off`.
  - `cloth`: her ponytail moves as cloth, as in solo. Off, it stays rigid.
  - `dyes`: her hair colour and other material variants. Off, each part has its mesh's own colours.
  - `effects`: her attack and skill effects (19 of EVE's effects, at most 4 at a time).
  - `dyes=off` and `effects=off` each also stop your game from sending your own, so the ghost of you in your friend's
    game lacks them too.
- `auto_coop_save`: see "Co-op saves" below. The photo, menu, chat, partner HUD and shared enemies settings are
  listed in [docs/players/settings.md](docs/players/settings.md#coop-settingstxt).

If the mod rejects a value, that setting keeps its default, and `UE4SS.log` gives the reason in a line that starts with
`[StellarCoop] settings:`. The `[StellarCoop] keys:` line lists the keys in use, and the `[StellarCoop] look:` line
what the ghost shows. Delete the file to get the defaults back.

The three looks have not been tried in game yet. Back up your saves before you play with one on (see "Saves and Steam
Cloud"). If the game crashes or the ghost looks wrong, turn that look off again.

With the console, `coop look <cloth|dyes|effects> <on|off>` turns one look on or off until the mod reloads (game start
or Ctrl+R) and builds the ghost again; `coop-settings.txt` does not change. `coop look` alone lists the three.

## Turn the mod off or on

- Off: close the game and delete `Mods/StellarCoop/enabled.txt`. If `Mods/mods.txt` has a `StellarCoop` line, set
  it to `StellarCoop : 0` too.
- On again: close the game and create an empty file named `enabled.txt` in `Mods/StellarCoop/`. If you changed the
  `StellarCoop` line in `mods.txt`, set it back to `StellarCoop : 1`.
- Uninstall: see "Uninstall" below.

## Saves and Steam Cloud

The mod reads your own saves to make separate co-op copies, and writes one of them only when you export a co-op save
over it, after a backup of that save (see "Co-op saves" below and
[docs/players/saves.md](docs/players/saves.md#what-the-mod-reads-and-writes)). Back up the saves anyway before you play with any mod:

1. Close the game.
2. Copy the save folder to a place outside the game and Steam folders.
   - Windows: `%LOCALAPPDATA%\SB\Saved\SaveGames\<your Steam ID>\`
   - Linux (Proton): `<Steam library>/steamapps/compatdata/3489700/pfx/drive_c/users/steamuser/AppData/Local/SB/Saved/SaveGames/<your Steam ID>/`

Steam Cloud syncs this folder. If a save looks wrong, do not start the game again. First turn Steam Cloud off for
Stellar Blade (right-click the game, Properties, General), so that the bad save does not replace the good copy in the
cloud. Then restore your backup.

## Co-op saves

`coop fight`, `coop nightop`, `coop challenge`, `coop no`, `coop recruiter`, `coop gift`, `coop pvp`, Doro races
(`coop race start` and the race rounds of a match), the fishing tournament, the photo hunt and the recruiter's Join to
the SBO lobby run only on a co-op save, a copy of your save, and never on your own saves (`coop nightop stop` and
`coop challenge stop` work on any save). The recruiter himself appears near Roxanne at each Xion load on any save,
your own saves included; there his Join changes nothing and a notice says why. The ghost, the keys and the Steam link
work on any save. Nothing is copied back to your own saves unless you export a co-op save (below). Items bought in Night
Operation's shop (`coop nightop shop` or `coop nightop buy`) and gifts (`coop gift`) go into or leave the co-op save you
play, never your own saves.

The mod makes the copies itself, in the save folder above: `StellarBladeCoop00.sav` to `StellarBladeCoop04.sav`, one
for each of your saves `StellarBladeSave00.sav` to `StellarBladeSave04.sav`. Once the game uses the copies, Continue,
Load Game and every save the game makes go to them.

On the title screen, once the mod's on-screen UI has loaded (a few seconds), the mod asks how to play. If you choose
Continue or Load Game before it shows, the game loads your own save, and the question comes back at the next title
screen. Up and down arrows (or W, Z and S) move, Enter selects, Esc is Decide later, and a left click selects the
choice under the mouse. On a controller, the D-pad or the left stick moves, A selects and B is Decide later. For 1 s
after the question shows, Enter, Space, A and a click do nothing, so a press meant for the title screen does not
answer it. The mod reads any controller the game reads, a DualSense with Steam Input off included. If the mod cannot
use the game's input, it reads XInput controllers only; a DualSense then needs Steam Input on for Stellar Blade
(see [docs/players/interface.md](docs/players/interface.md#controller)). With no answer for 60 s, the question closes as Decide later.

- Convert and play co-op (Play co-op once copies exist): the mod copies your saves, then switches the game to the
  copies. Before the first copies, it backs up every `StellarBlade*.sav` of your account into
  `%LOCALAPPDATA%\SB\Saved\StellarCoopBackups\<UTC time>\`. Then use Load Game (see below).
- Play solo normally, or Decide later: the game uses your own saves. The question comes back the next time the title
  screen shows, or once more on the same title screen if you then accept a friend's invite.
- Don't ask again: sets `auto_coop_save=always` in `coop-settings.txt`, then plays co-op. From then on the mod switches
  to the copies at every title screen without asking.

On the title screen where the switch happens, use Load Game and pick the slot by its number. The game reads its slot
list when it starts and each time you return to the title, so until then the list shows your own saves' details while
every load and save goes to the copies. Continue may then load a different slot from the one you last played in co-op,
and a slot the list shows as empty can hold a copy you played in co-op: a New Game there replaces it without asking.

If the copies cannot be made, the question says why and offers only the solo choices. `coop status` shows
`slot=coop ... saves=coop` once a copy is loaded. The co-op saves ran in game on 2026-10-21 and 2026-10-27, but back
up your saves first anyway (see "Saves and Steam Cloud").

More about the copies:

- Once a co-op save has been loaded, the game keeps using the copies until it restarts. To play your own saves again,
  restart the game and choose Play solo normally.
- `auto_coop_save` (in Options, Saves > Co-op saves, or in `coop-settings.txt`) is `ask` (the question, the default),
  `always` or `off` (no copies; see "Manual co-op slot" below).
- A copy you have not played in co-op follows your own save: the next conversion copies your save again if it changed.
  A copy you played in co-op is never replaced by itself. To start it over from your own save, type
  `coop saves refresh N` twice at the title (N is the slot, 0 to 4) while the game uses your own saves (with
  `always`, type `coop saves main` first); the old copy goes to `StellarCoopBackups` first.
- While the game uses the copies, `CO-OP SAVES` shows at the top right of the title screen, and the question does
  not show.
- Steam Cloud syncs the copies like your own saves, so they take up to the same space again.
- To keep a co-op character without the mod, type `coop saves export N M` twice within 10 s at the title (N is the
  co-op slot, M the slot of yours it goes to, both 0 to 4). The mod backs up `StellarBladeSave0M.sav` into
  `StellarCoopBackups`, then writes `StellarBladeCoop0N.sav` over it, unchanged. It refuses a co-op save that still
  holds the mod's items (Burst Stimpack, Beta Stimpack, Shock Bolt, Beta Seed), has Shock Bolts as the selected ammo,
  or names the cut Matrix XIII area as its map, its camp, its last full camp or its last simple camp, and
  `coop-link.log` says what to use up, sell or switch, or to rest at a full camp (one with a phone booth) outside the
  area. It also refuses a developer save that `coop shortcut load` wrote in co-op slot 4
  (`StellarBladeCoop04.sav`, the title's fifth slot), played or not. Quit the game afterwards: until it restarts, the
  title's slot list shows the slot's old details. The export has not been tried in game yet. See
  [docs/players/saves.md](docs/players/saves.md#co-op-saves).
- A co-op save that started New Game+ while it held any of these keeps them in the game's New Game+ copy of the
  inventory and camps, which playing does not change, so the export keeps refusing it. Only the copy by hand below
  takes it out.
- By hand: close the game, back up the save folder, then copy `StellarBladeCoop0N.sav` to a free
  `StellarBladeSave0M.sav` name in the same folder. The game loads it like any save, but nothing checks it for the
  mod's items first.

### Manual co-op slot (auto_coop_save=off)

With `auto_coop_save=off`, the mod asks nothing and makes no copies by itself. The co-op save is then one of your five
slots: a copy of your save under a free name from `StellarBladeSave00.sav` to `StellarBladeSave04.sav`, made with the
game closed, and named on one line of `StellarCoopSlot.txt` (UTF-8) in the same folder. On Linux,
`python3 tools/save_guard.py slot SOURCE TARGET` makes both and backs up first. Load that slot: `coop status` shows
`slot=coop index=N marker=N`. See [docs/players/saves.md](docs/players/saves.md#manual-co-op-slot).

### Recovery

- To stop using the co-op saves, set `auto_coop_save=off` (or choose Play solo normally) and restart the game. The
  copies stay in the folder, unused.
- To stop using a manual co-op slot, close the game and move `StellarCoopSlot.txt` out of the folder. The copy then
  counts as an ordinary save. To get back a save you moved out to free a slot, first move `StellarCoopSlot.txt` out,
  then move the copy into a different folder (or rename it), and move that save back in.
- `save_guard.py restore` of a backup older than the manual co-op slot removes `StellarCoopSlot.txt`, and says so. If
  you restore such a backup by hand, move `StellarCoopSlot.txt` out first; otherwise it names one of your own saves.
- Continue loads the slot you played last, except on the title screen where the mod switched to the copies (see
  "Co-op saves"). Load Game lets you pick the slot, and `coop status` says which slot is loaded.
- New Game and New Game+ ask which slot to overwrite, among the co-op copies while the game uses them. That prompt
  comes from the game, not from the mod.
- Steam Cloud never syncs `StellarCoopSaves.txt` (the mod's list of copies) or `StellarCoopSlot.txt`. On another PC
  every co-op copy counts as played, so the mod never replaces one there, and a manual co-op slot counts as an
  ordinary save.
- After any `coop no` subcommand, end the game by killing it (Linux: `pkill -9 -f SB-Win64-Shipping`; Windows: Task
  Manager, End task), not by Quit from the menu, which saves. Never load another save in that run: the probe's changes
  stay in the game until it ends.
- After `coop recruiter`, do the same: kill the game instead of using Quit, and never load another save in that run
  (the recruiter's changes also stay in the game until it ends). It is not yet known whether the game saves the
  spawned recruiter (a Xion guard), so keep Steam Cloud off, back up the saves before the run, and restore that backup
  once the game is closed. The restore also undoes that run's progress in the co-op save, and removes the recruiter
  from it if the game saved him.
  - Linux, from the repository: `python3 tools/save_guard.py backup` before the run. After it,
    `python3 tools/save_guard.py check`, then `python3 tools/save_guard.py restore <backup> --yes`, where `<backup>`
    is the folder name that `backup` printed.
  - Windows: copy the save folder before the run, as in "Saves and Steam Cloud". After it, look in File Explorer at
    which files have a newer modified time, then copy the backup back over the save folder.
  - Only these files may differ: the co-op save you played (`StellarBladeCoop0N.sav`, or the manual co-op slot) and
    its `Backup/` copy, the game's own `StellarBladeSetting.sav` and its `Backup/` copy, the `steam_autocloud.vdf`
    files and other mods' saves. Any other `StellarBladeSave0N.sav`, or its `Backup/` copy, means the run wrote one of
    your own slots. The restore puts it back; please send the logs (see "Which logs to send").

## Check the files

`SHA256SUMS.txt` lists the SHA-256 sum of every other file in the folder, including `INSTALL.md`, `LICENSE`, `NOTICE`,
`EXCLUDED-PARTIES.md` and `CHANGELOG.md`.

- Linux: in the `StellarCoop` folder, run `sha256sum -c SHA256SUMS.txt`. Every file must pass (`OK`, or the same word in
  your language). A mismatch ends with a warning.
- Windows: in PowerShell, in the `StellarCoop` folder, run `Get-FileHash <file> -Algorithm SHA256` for each file, for
  example `Get-FileHash StellarCoop.dll -Algorithm SHA256`. The hash must match that file's line of `SHA256SUMS.txt`
  (upper or lower case does not matter). Check at least `StellarCoop.dll` and `CHANGELOG.md`.

The build is reproducible: `python3 tools/install.py --zip` on a commit, with clang-cl 23.1.3, xwin's Windows SDK
10.0.26100 and MSVC CRT 14.44.35220, gives the same `StellarCoop.dll` bytes, so anyone with the repository can compare
its sum. The build writes the commit's `git describe` into the DLL, and the zip's name must show the same version.

## Windows Defender and SmartScreen

`StellarCoop.dll` is not code-signed, so Windows Defender or SmartScreen may warn about it or quarantine it. Check its
sum first (see above). If the sum matches and the file was quarantined, you can restore it from Windows Security,
Protection history. Without the DLL the Steam link does not start, and `UE4SS.log` says so.

## Uninstall

Close the game first.

- Installed from the zip (Windows or Linux): delete the `Mods/StellarCoop` folder. It holds the logs,
  `coop-settings.txt`, `coop-guide.txt`, `coop-records.txt`, the Night Operation shop points (`coop-night-*.txt`), the
  `coop gift` mailbox (`coop-gift-*.txt`), the Doro race tracks (`coop-track-*.txt` and `coop-tracks.txt`), the
  places of your parked bike (`coop-bike-<steamid>-*.txt`) and the block list (`coop-blocked.txt`), so first copy out
  what you want to keep. If you added a `StellarCoop` line to `Mods/mods.txt`, remove that line.
- Installed with `tools/install.py` (Linux), from the Stellar Blade Online repository:
  `python3 tools/install.py --uninstall` (add `--dry-run` first to see what it would do, and
  `--game <Stellar Blade folder>` if the game is not in the script's default folder). It backs up the whole folder into
  `~/StellarCoop-install-backups`, then removes it. It removes only a folder it installed (one with
  `install-manifest.txt`); delete a folder copied from the zip by hand, as above. It never edits `mods.txt`, but it
  reports a line there that still names StellarCoop, for you to remove.

Your saves stay, and so do the co-op copies, `StellarCoopSaves.txt`, the shared quests' records
(`StellarCoopQuests0N.txt`), a shortcut save's mark (`StellarCoopShortcut04.txt`), the backups in `StellarCoopBackups`
and `StellarCoopSlot.txt`. The game ignores them without the mod. To keep a co-op character, see "Co-op saves" above.

## Which logs to send

If something goes wrong, close the game and send these files before you start the game again, because each launch
overwrites `UE4SS.log` and moves `coop-link.log` to `coop-link.old.log`. Some of the files may not exist; send the ones
that do.

- `Mods/StellarCoop/coop-report.txt`
- `Mods/StellarCoop/coop-link.log`
- `Mods/StellarCoop/coop-link.old.log`
- `ue4ss/UE4SS.log`
- `Mods/StellarCoop/nightop-probe.txt`, only if you ran the Night Operation probe (`coop no`)
- `Mods/StellarCoop/coop-quests.log`, only if shared quests were on

The mod masks SteamIDs and join codes in what it writes to these files. A SteamID shows as `***` and its last 4 digits
(`***5678`), which still tell the players in one report apart. A join code shows its first 3 characters (`ABC-****`),
as does a lobby ID, whose digits would give its code away. The files still contain your Steam name, the other players'
Steam names and folder paths, which may include your Windows user name. They contain no passwords. Logs from an older
version of the mod keep the full IDs, as does the `coop-link.old.log` of the first run after an update. You can read
the files before you send them.

When you test with a friend, the player who leads the test types `coop mark <step>` in the console before each step,
for example `coop mark 3 lift`. Each mark puts a numbered line with that text in both players' `coop-link.log` and
`UE4SS.log` (see [usage.md](docs/usage.md#coop-mark)), so the four logs line up step by step. The text of each mark
stays in the logs you send.

## License

Stellar Blade Online is licensed under the SBO License 1.0 or any later version, in `LICENSE`. `EXCLUDED-PARTIES.md`
lists the parties it excludes, and `NOTICE` holds the credits and the parts under other terms. Versions up to 0.9.0 stay
under GPL-3.0-or-later.

The release zip does not contain `Assets/MotherSphere.png`, the Mother Sphere art by timediffer24
(https://x.com/timediffer24) that the guide shows when the file is in the mod folder. It was given to this project and
is not covered by the SBO License. Without it, the guide opens with its text only.
