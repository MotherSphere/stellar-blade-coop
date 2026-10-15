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

Today the mod does not read or write saves. Back them up anyway before you play with any mod:

1. Close the game.
2. Copy the save folder to a place outside the game and Steam folders.
   - Windows: `%LOCALAPPDATA%\SB\Saved\SaveGames\<your Steam ID>\`
   - Linux (Proton): `<Steam library>/steamapps/compatdata/3489700/pfx/drive_c/users/steamuser/AppData/Local/SB/Saved/SaveGames/<your Steam ID>/`

Steam Cloud syncs this folder. If a save ever looks wrong, do not start the game again. First turn Steam Cloud off for
Stellar Blade (right-click the game, Properties, General), so the bad save does not replace the good copy in the
cloud. Then restore your backup.

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
