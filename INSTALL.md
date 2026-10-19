# Installing StellarCoop

StellarCoop is an experimental co-op mod for Stellar Blade on PC. It runs inside UE4SS. These steps cover Windows and
Linux with Proton; a Windows PC and a Linux PC have played together.
The rest of the documentation is in [docs/](https://github.com/MotherSphere/stellar-blade-coop/tree/main/docs) in the
repository.

**Close the game before you copy, change or delete any mod file.**

## Requirements

- Stellar Blade on Steam, game build 24463856. `coop status` reports the build as `build=...` in `UE4SS.log`.
- UE4SS, as packaged in "Stellar Blade UE4SS 1.3" (UE4SS v3.0.1 Beta, git `08a0733`). The first lines of
  `UE4SS.log` show the version, for example `UE4SS - v3.0.1 Beta #0 - Git SHA #08a0733`.
- Optional: ConsoleEnablerMod, which comes with that UE4SS package, for the `coop` console commands. The keys (see
  "Keys and settings") work without it. It needs the line `ConsoleEnablerMod : 1` in `Mods/mods.txt`. In game, `F10`
  or `~` (tilde) opens the console.

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
5. Start the game, load a save and press `F6`. A line of text appears above EVE for 4 s, for example `Co-op: not in a
   session.` `UE4SS.log` gets the same text in a line that contains `[StellarCoop] OK:`.
   If no line appears, close the game and look in `UE4SS.log` for lines with `[StellarCoop]`. `Native part not loaded`
   means that `StellarCoop.dll` is missing or quarantined (see "Windows Defender and SmartScreen"). The keys do not
   work without it.

UE4SS starts every mod folder that contains an `enabled.txt` file, so you do not need to edit `mods.txt`.

On Linux, you can build and install the mod from the StellarCoop repository instead, with `python3 tools/install.py`.
Add `--game <Stellar Blade folder>` if the game is not in the script's default folder (`--help` shows it). The script
first backs up the files it replaces into `~/StellarCoop-install-backups`.

### Update

`CHANGELOG.md` in the zip gives the zip's version and its features and fixes, newest first. Both players must update
together. Two games with different protocols cannot link, and the player who tries to join sees
`Version mismatch: that game runs protocol ..., build ...; yours runs ...`.

1. Close the game.
2. From the old `Mods/StellarCoop` folder, copy out what you want to keep: `coop-settings.txt` if you changed it, and
   any log you still want to send. The zip has no `coop-settings.txt`; when the file is missing, the mod writes the
   defaults again.
3. Delete the old `StellarCoop` folder, so that no file of the old version remains.
4. Install the new zip with install steps 2 to 4, and put `coop-settings.txt` back into the new folder.
5. Do install step 5, with your status key if you changed it.

## Keys and settings

- `F5` (host) opens a friends-only session and the Steam invite dialog, where you pick your friend. While you host,
  `F5` opens the dialog again. A guest cannot host and must leave the session first.
- `F6` (status) shows one line above EVE and writes it to `UE4SS.log`, for example `Co-op: hosting Alex.`
- `F8` leaves the session. When the host leaves, the guest leaves too.

Your friend accepts the invite in Steam. If their game is closed, Steam starts it. They join once they have loaded a
save, and both ghosts turn on automatically. Session events (a friend joined or left, connection lost, a rejoin)
show as a line above EVE for 4 s and also go to `UE4SS.log`.

The mod writes `Mods/StellarCoop/coop-settings.txt` the first time the game starts with it. To change a setting, close
the game, edit the file, then start the game again:

- `host_key`, `status_key`, `leave_key`: `F1` to `F12` except `F10` (it opens the console), with at most one of
  `Shift+`, `Ctrl+` or `Alt+` in front, for example `host_key=Shift+F7`. If two actions share one key, all three keys
  go back to `F5`, `F6` and `F8`.
- `name_tag`: `on` or `off`, your friend's Steam name above their ghost.
- `send_rate`: poses sent to your friend per second, from 10 to 30 (20 by default).
- `cloth`, `dyes`, `effects`: `on` or `off`, what your friend's ghost shows. All three are off by default. The file
  names them only in a comment, so add a line such as `cloth=on` to turn one on.
  - `cloth`: her ponytail swings as cloth. Off, it stays rigid.
  - `dyes`: her hair colour and other material variants. Off, each part has its mesh's own colours.
  - `effects`: her attack and skill effects (19 of EVE's effects, at most 4 at a time).
  - `dyes=off` and `effects=off` each also stop your game from sending your own, so the ghost of you in your friend's
    game lacks them too.

If the mod rejects a value, that setting keeps its default, and `UE4SS.log` gives the reason in a line that starts with
`[StellarCoop] settings:`. The `[StellarCoop] keys:` line lists the keys in use, and the `[StellarCoop] look:` line
what the ghost shows. Delete the file to get the defaults back.

The three looks have not been tried in game yet. Back up your saves before you turn one on (see "Saves and Steam
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

The mod never reads or writes a save. It reads only `StellarCoopSlot.txt`, a text file beside the saves (see "Co-op
save slot" below). Back up the saves anyway before you play with any mod:

1. Close the game.
2. Copy the save folder to a place outside the game and Steam folders.
   - Windows: `%LOCALAPPDATA%\SB\Saved\SaveGames\<your Steam ID>\`
   - Linux (Proton): `<Steam library>/steamapps/compatdata/3489700/pfx/drive_c/users/steamuser/AppData/Local/SB/Saved/SaveGames/<your Steam ID>/`

Steam Cloud syncs this folder. If a save looks wrong, do not start the game again. First turn Steam Cloud off for
Stellar Blade (right-click the game, Properties, General), so that the bad save does not replace the good copy in the
cloud. Then restore your backup.

## Co-op save slot

`coop no`, `coop recruiter` and `coop fight` run only on a copy of your save, the co-op save slot, and never on your
own slots. The ghost, the keys and the Steam link work on any save. Make the copy once, with the game closed, before the
first co-op session. Nothing is copied back to your own slots.

The game has five save slots: the files `StellarBladeSave00.sav` to `StellarBladeSave04.sav` in the save folder above.
The co-op slot is the file that `StellarCoopSlot.txt`, in the same folder, names.

### Windows

With the game closed:

1. Copy the whole `%LOCALAPPDATA%\SB\Saved\SaveGames` folder into your Documents folder, as a backup.
2. In File Explorer, turn on View > Show > File name extensions.
3. Open `%LOCALAPPDATA%\SB\Saved\SaveGames\<your Steam ID>`. Find a name from `StellarBladeSave00.sav` to
   `StellarBladeSave04.sav` that no file has. If all five exist, move the one you need least into your backup folder.
   Never delete it.
4. Copy the save you play, paste it into the same folder, and rename the copy to the free name, for example
   `StellarBladeSave04.sav`.
5. In Notepad, type that name alone on one line, for example `StellarBladeSave04.sav`. Use File > Save As, in the
   same folder: file name `StellarCoopSlot.txt`, Save as type `All files (*.*)`, Encoding `UTF-8`.
6. Check in File Explorer that the file is named `StellarCoopSlot.txt`, not `StellarCoopSlot.txt.txt`.
7. Start the game, use Load Game and pick the copy (it looks the same as the save it came from). `coop status` must
   show `slot=coop index=N marker=N`, where N is the copy's number (4 for `StellarBladeSave04.sav`). Without the
   console, `UE4SS.log` has the same at each load, in a line `[StellarCoop] link: slot=...`.

If it shows something else:

- `slot=main index=0 marker=4`: another slot is loaded (here file 00). Go back to the title and load the other entry.
- `marker=none`: there is no `StellarCoopSlot.txt` in that folder, often because it is named
  `StellarCoopSlot.txt.txt`.
- `marker=bad`: the file's text or encoding is wrong. It must hold one line with the name, saved as UTF-8.
- `slot=none`: no save is loaded yet (the title screen).

### Linux (Proton)

`tools/save_guard.py` comes with the StellarCoop repository, not with the zip. From the repository, with the game
closed:

1. `python3 tools/save_guard.py backup`
2. If all five slots exist, move the one you need least out of the save folder, into your backup folder. Never delete
   it.
3. `python3 tools/save_guard.py slot SOURCE TARGET --dry-run`, where SOURCE is the number of the save you play and
   TARGET the free number (for example `slot 0 4` when you play `StellarBladeSave00.sav` and `StellarBladeSave04.sav`
   is free). It checks the copy and writes nothing.
4. The same command without `--dry-run`.

`slot` refuses to run while the game runs, and refuses a target slot that holds a save other than the co-op slot. It
makes its own safety backup, then writes `StellarCoopSlot.txt` and the copy. Replacing the co-op slot with a new copy
needs `--yes`. `--saves` gives another save folder (see `--help`). Then load the copy as in Windows step 7.

### Recovery

- To stop using the co-op slot, close the game and move `StellarCoopSlot.txt` out of the folder. The copy then counts
  as an ordinary save. To get back a save you moved out to free a slot, first move `StellarCoopSlot.txt` out, then
  move the copy into a different folder (or rename it), and move that save back in.
- `save_guard.py restore` of a backup older than the co-op slot removes `StellarCoopSlot.txt`, and says so. If you
  restore such a backup by hand, move `StellarCoopSlot.txt` out first; otherwise it names one of your own saves.
- Continue loads the slot you played last. Load Game lets you pick the slot, and `coop status` says which slot is
  loaded.
- New Game and New Game+ ask which slot to overwrite. That prompt comes from the game, not from the mod.
- Steam Cloud syncs the copied `.sav` but never `StellarCoopSlot.txt`. On another PC the copy counts as an ordinary
  save, and `coop no` refuses to run there.
- After any `coop no` subcommand, end the game by killing it (Linux: `pkill -9 -f SB-Win64-Shipping`; Windows: Task
  Manager, End task), not by Quit from the menu, which saves. Never load another save in that run: the probe's changes
  stay in the game until it ends.
- After `coop recruiter`, do the same: kill the game instead of using Quit, and never load another save in that run
  (the recruiter's changes also stay in the game until it ends). It is not yet known whether the game saves the
  spawned recruiter (a Xion guard), so keep Steam Cloud off, back up the saves before the run, and restore that backup
  once the game is closed. The restore also undoes that run's progress in the co-op slot, and removes the recruiter
  from it if the game saved him.
  - Linux, from the repository: `python3 tools/save_guard.py backup` before the run. After it,
    `python3 tools/save_guard.py check`, then `python3 tools/save_guard.py restore <backup> --yes`, where `<backup>`
    is the folder name that `backup` printed.
  - Windows: copy the save folder before the run, as in "Saves and Steam Cloud". After it, look in File Explorer at
    which files have a newer modified time, then copy the backup back over the save folder.
  - Only these files may differ: the co-op slot and its `Backup/StellarBladeSave0N_Old.sav` copy, the game's own
    `StellarBladeSetting.sav` and its `Backup/` copy, the `steam_autocloud.vdf` files and other mods' saves. Any other
    `StellarBladeSave0N.sav`, or its `Backup/` copy, means the run wrote one of your own slots. The restore puts it
    back; please send the logs (see "Which logs to send").

## Check the files

`SHA256SUMS.txt` lists the SHA-256 sum of every other file in the folder, including `INSTALL.md`, `LICENSE` and
`CHANGELOG.md`.

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

- Installed from the zip (Windows or Linux): delete the `Mods/StellarCoop` folder. It holds the logs and
  `coop-settings.txt`, so first copy out what you want to keep. If you added a `StellarCoop` line to `Mods/mods.txt`,
  remove that line.
- Installed with `tools/install.py` (Linux), from the StellarCoop repository: `python3 tools/install.py --uninstall`
  (add `--dry-run` first to see what it would do, and `--game <Stellar Blade folder>` if the game is not in the
  script's default folder). It backs up the whole folder into `~/StellarCoop-install-backups`, then removes it. It
  removes only a folder it installed (one with `install-manifest.txt`); delete a folder copied from the zip by hand, as
  above. It never edits `mods.txt`, but it reports a line there that still names StellarCoop, for you to remove.

Your saves, the co-op save slot and `StellarCoopSlot.txt` stay. To stop using the co-op slot too, see "Recovery" above.

## Which logs to send

If something goes wrong, close the game and send these files before you start the game again, because each launch
overwrites `UE4SS.log` and moves `coop-link.log` to `coop-link.old.log`. Some of the files may not exist; send the ones
that do.

- `Mods/StellarCoop/coop-report.txt`
- `Mods/StellarCoop/coop-link.log`
- `Mods/StellarCoop/coop-link.old.log`
- `ue4ss/UE4SS.log`
- `Mods/StellarCoop/nightop-probe.txt`, only if you ran the Night Operation probe (`coop no`)

They contain your Steam ID and Steam name, the other player's Steam ID and Steam name, lobby IDs and folder paths,
which may include your Windows user name. They contain no passwords. You can read them before you send them.
