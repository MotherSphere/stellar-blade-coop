# Installing StellarCoop

StellarCoop is an experimental co-op mod for Stellar Blade (PC). It runs inside UE4SS. These steps work on Windows
and on Linux with Proton.

**Close the game before you copy, change or delete any mod file.**

## Requirements

- Stellar Blade on Steam, game build 24463856. `coop status` reports the build as `build=...` in `UE4SS.log`.
- UE4SS, as packaged in "Stellar Blade UE4SS 1.3" (UE4SS v3.0.1 Beta, git `08a0733`). The first lines of
  `UE4SS.log` show the version, for example `UE4SS - v3.0.1 Beta #0 - Git SHA #08a0733`.
- Optional: ConsoleEnablerMod, which comes with that UE4SS package, for the `coop` console commands. The keys (see
  "Keys and settings") work without it. To use it, `Mods/mods.txt` has the line `ConsoleEnablerMod : 1`; in game, it
  opens the console with `F10` or `~` (Tilde).

## Find the folders

- Game folder: in Steam, right-click Stellar Blade, then Manage, then Browse local files.
- UE4SS folder: `SB/Binaries/Win64/ue4ss/` inside the game folder. It holds `UE4SS.dll`, `UE4SS.log` and `Mods/`.
- Mods folder: `SB/Binaries/Win64/ue4ss/Mods/`.

## Install

1. Close the game.
2. Unzip `StellarCoop-<version>.zip`. You get a folder named `StellarCoop`. Windows "Extract All" may put it one
   level deeper, in `StellarCoop-<version>\StellarCoop\`: use that inner `StellarCoop` folder.
3. Optional but recommended: check the files (see "Check the files" below).
4. Copy the whole `StellarCoop` folder (the one that holds `enabled.txt`) into the Mods folder. The result must be
   `SB/Binaries/Win64/ue4ss/Mods/StellarCoop/Scripts/main.lua`, with `StellarCoop.dll` and `enabled.txt` next to
   `Scripts/`.
5. Start the game, load a save and press `F6`. A line of text above EVE answers, for example `Co-op: not in a
   session.`, for 4 s. `UE4SS.log` has the same answer, in a line that contains `[StellarCoop] OK:`.
   No line? Close the game and look in `UE4SS.log` for lines with `[StellarCoop]`: `Native part not loaded` means
   `StellarCoop.dll` is missing or quarantined (see "Windows Defender and SmartScreen"); the keys need it.

You do not need to edit `mods.txt`: UE4SS starts every mod folder that contains an `enabled.txt` file.

To update, close the game, delete the old `StellarCoop` folder (first copy out any log you still want to send), then
install the new one. If you changed `coop-settings.txt`, keep it: copy it out of the old folder first and back into
the new one after. The zip never holds that file; without it, the mod writes the defaults again.

## Keys and settings

- `F5`, host: opens a friends-only session and the Steam invite dialog; pick your friend there. While you host, it
  opens the dialog again. A guest cannot host: leave first.
- `F6`, status: one line above EVE and in `UE4SS.log`, for example `Co-op: hosting Kaanta.`
- `F8`, leave the session. When the host leaves, the guest leaves too.

Your friend accepts the invite in Steam; if her game is closed, Steam starts it. She joins once she has loaded a save,
and both ghosts turn on by themselves. Session events (a friend joined or left, connection lost, a rejoin) show as a
line above EVE for 4 s, and go to `UE4SS.log` too.

The first start writes `Mods/StellarCoop/coop-settings.txt`. To change it, close the game, edit the file, then start
the game again:

- `host_key`, `status_key`, `leave_key`: `F1` to `F12` except `F10` (it opens the console), with at most one of
  `Shift+`, `Ctrl+` or `Alt+` in front, for example `host_key=Shift+F7`. Two actions on one key put all three keys
  back to `F5`, `F6` and `F8`.
- `name_tag`: `on` or `off`, your friend's Steam name above her ghost.
- `send_rate`: poses sent to your friend a second, from 10 to 30 (20 by default).

A value the mod refuses keeps its default, and `UE4SS.log` says why in a line that starts with
`[StellarCoop] settings:`. The `[StellarCoop] keys:` line gives the keys in use. Delete the file to get the defaults
back.

## Turn the mod off or on

- Off: close the game and delete `Mods/StellarCoop/enabled.txt`. If `Mods/mods.txt` has a `StellarCoop` line, set
  it to `StellarCoop : 0` too.
- On again: close the game and create an empty file named `enabled.txt` in `Mods/StellarCoop/`. If you changed the
  `StellarCoop` line in `mods.txt`, set it back to `StellarCoop : 1`.
- Uninstall: close the game and delete the `Mods/StellarCoop` folder.

## Saves and Steam Cloud

The mod never reads or writes a save. It reads only `StellarCoopSlot.txt`, a text file beside the saves (see "Co-op
save slot" below). Back the saves up anyway before you play with any mod:

1. Close the game.
2. Copy the save folder to a place outside the game and Steam folders.
   - Windows: `%LOCALAPPDATA%\SB\Saved\SaveGames\<your Steam ID>\`
   - Linux (Proton): `<Steam library>/steamapps/compatdata/3489700/pfx/drive_c/users/steamuser/AppData/Local/SB/Saved/SaveGames/<your Steam ID>/`

Steam Cloud syncs this folder. If a save ever looks wrong, do not start the game again. First turn Steam Cloud off for
Stellar Blade (right-click the game, Properties, General), so the bad save does not replace the good copy in the
cloud. Then restore your backup.

## Co-op save slot

`coop no` (and the shared features of later versions) runs only on a copy of your save, the co-op save slot, never on
your own slots. The ghost, the keys and the Steam link work on any save. Make the copy once, with the game closed,
before the first co-op session. Nothing is ever copied back to your own slots.

The game has five save slots: the files `StellarBladeSave00.sav` to `StellarBladeSave04.sav` in the save folder above.
The co-op slot is the one that `StellarCoopSlot.txt`, in the same folder, names.

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
- `marker=none`: no `StellarCoopSlot.txt` in that folder, often because it is named `StellarCoopSlot.txt.txt`.
- `marker=bad`: the file's text or encoding is wrong: one line with the name, saved as UTF-8.
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

`slot` refuses while the game runs and refuses an occupied slot that is not the co-op slot. It makes its own safety
backup, then writes `StellarCoopSlot.txt` and the copy. Replacing the co-op slot with a new copy needs `--yes`.
`--saves` gives another save folder (see `--help`). Then load the copy as in Windows step 7.

### Recovery

- The mod never writes your own saves, and nothing is ever copied back from the co-op slot.
- To stop using the co-op slot, close the game and move `StellarCoopSlot.txt` out of the folder. The copy then counts
  as an ordinary save. To get back a save you moved out, then, with `StellarCoopSlot.txt` already out, move the copy
  into a different folder (or rename it), and move that save back in.
- `save_guard.py restore` of a backup older than the co-op slot removes `StellarCoopSlot.txt`, and says so. If you
  restore such a backup by hand, move `StellarCoopSlot.txt` out first: otherwise it names one of your own saves.
- Continue loads whichever slot you played last. Load Game is clearer, and `coop status` says which slot is loaded.
- New Game and New Game+ ask which slot to overwrite: that is the game's own behaviour.
- Steam Cloud syncs the copied `.sav` but never `StellarCoopSlot.txt`. On another PC the copy counts as an ordinary
  save, and `coop no` refuses there.
- After any `coop no` subcommand, end the game by killing it (Linux: `pkill -9 -f SB-Win64-Shipping`; Windows: Task
  Manager, End task), not by Quit from the menu, which saves. Never load another save in that run: the probe's changes
  stay in the game until it ends.

## Check the files

`SHA256SUMS.txt` lists the SHA-256 sum of every other file in the folder.

- Linux: in the `StellarCoop` folder, run `sha256sum -c SHA256SUMS.txt`. Every file must pass (`OK`, or the same word in your
  language). A mismatch ends with a warning.
- Windows: in PowerShell, in the `StellarCoop` folder, run `Get-FileHash StellarCoop.dll`. The hash must match the
  `StellarCoop.dll` line of `SHA256SUMS.txt` (upper or lower case does not matter). Do the same for other files if
  you wish.

## Windows Defender and SmartScreen

`StellarCoop.dll` is not code-signed, so Windows Defender or SmartScreen may warn about it or quarantine it. Check its
sum first (see above). If the sum matches and the file was quarantined, you can restore it from Windows Security,
Protection history. Without the DLL the Steam link does not start, and `UE4SS.log` says so.

## Which logs to send

If something goes wrong, close the game and send these files before you start the game again: each launch overwrites
`UE4SS.log` and moves `coop-link.log` to `coop-link.old.log`. Some files may be missing, which is fine.

- `Mods/StellarCoop/coop-report.txt`
- `Mods/StellarCoop/coop-link.log`
- `Mods/StellarCoop/coop-link.old.log`
- `ue4ss/UE4SS.log`
- `Mods/StellarCoop/nightop-probe.txt`, only after the T6 test (`coop no`)

They contain your Steam ID and Steam name, the other player's Steam ID and Steam name, lobby IDs and folder paths,
which may include your Windows user name.
They contain no passwords. Read them before you send them if you wish.
