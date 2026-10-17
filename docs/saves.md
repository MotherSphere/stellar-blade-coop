# Saves and save safety

Your saves matter more than any mod. This page says what StellarCoop never touches, how to back your saves up with
`tools/save_guard.py`, how to handle Steam Cloud, what the co-op save slot is, and how to recover. The step-by-step
procedures for players are in [INSTALL.md](../INSTALL.md#saves-and-steam-cloud); this page explains the why.

## What the mod never touches

- The mod **never reads or writes a save**, the inventory, unlocks or equipment.
- **Nothing is copied between two players' games.** The ghost is display only: a plain actor that is not a Pawn, so
  lock-on, AI and saves never see it, and nothing of it is written to a save. The meshes it loads are only brought into
  memory: nothing is worn or unlocked.
- The only file the mod reads beside the saves is the co-op marker **`StellarCoopSlot.txt`** (every 5 s), which names
  the co-op save slot.
- The native part also **watches** the save folder: every 5 s it lists the names, sizes and write times of the files
  there, without ever opening a save, and logs every change in `coop-link.log`. `coop report` sums them up. This shows
  when the game itself writes its saves.
- On the pinned game build only, and until `coop off`, it reads which slot the game entered (every 250 ms), for the
  `slot=` line of `coop status`.

Apart from a restore putting a backup back, the only save anything in this project writes is the co-op slot's copy,
made by `tools/save_guard.py slot` with the game closed and after a safety backup. It is never copied back.

## Where the saves are

- Windows: `%LOCALAPPDATA%\SB\Saved\SaveGames\<your Steam ID>\`
- Linux (Proton): `<Steam library>/steamapps/compatdata/3489700/pfx/drive_c/users/steamuser/AppData/Local/SB/Saved/SaveGames/<your Steam ID>/`

The game has five save slots: the files `StellarBladeSave00.sav` to `StellarBladeSave04.sav`.

## Backups

Back the saves up before you play with any mod, and always before a Night Operation preview or a new look.

**On Windows**, with the game closed, copy the whole `SaveGames` folder to a place outside the game and Steam folders
(see [INSTALL.md](../INSTALL.md#saves-and-steam-cloud)).

**On Linux**, `tools/save_guard.py` comes with the repository (not with the release zip). It refuses to run while the
game runs:

| Command | What it does |
| --- | --- |
| `python3 tools/save_guard.py backup` | Copies the whole `SaveGames` folder into `~/StellarBlade-save-backups/<UTC time>/`, with a `SHA256SUMS.txt` |
| `python3 tools/save_guard.py check [--from BACKUP]` | Lists files added, removed or changed since a backup (the latest by default); exit code 0 if none, 1 if any |
| `python3 tools/save_guard.py restore BACKUP --yes` | Copies a backup back over the saves, after a safety backup of the current ones |
| `python3 tools/save_guard.py slot SOURCE TARGET` | Makes the co-op save slot (see below) |

Details:

- `--saves <folder>` gives your `SaveGames` folder (the default points at one particular Steam library; see `--help`),
  and `--to <folder>` the backup folder. Backups must live outside the game, its Proton prefix and the save folder.
- A save folder that is missing (a mistyped path, an unmounted drive) or that holds symbolic links is refused, never
  read as "every save removed".
- `restore` needs `--yes`, checks the backup against its `SHA256SUMS.txt` first, makes a safety backup of the current
  saves, and never deletes a save: a file that is not in the backup is left in place, and said. A restore of a backup
  older than the co-op slot removes `StellarCoopSlot.txt` (a copy is in the safety backup), and says so, so the slot it
  named is an ordinary slot again.
- Exit code 2 means an error; 1 is kept for "check found changes".

## Steam Cloud

Steam Cloud syncs the save folder. If a save ever looks wrong, do not start the game again: first turn Steam Cloud off
for Stellar Blade (right-click the game, Properties, General), so the bad save does not replace the good copy in the
cloud. Then restore your backup.

Keep Steam Cloud off during Night Operation preview runs and while you test new features.

Steam Cloud syncs the co-op slot's `.sav` copy but never `StellarCoopSlot.txt`. On another PC the copy counts as an
ordinary save, and the previews refuse to run there.

## The co-op save slot

Some features run only on a copy of your save, the **co-op save slot**, never on your own slots: today the two Night
Operation previews (`coop no` and `coop recruiter`), and the shared features of later versions. The ghost, the keys and
the Steam link work on any save. Nothing is ever copied back from the co-op slot to your own slots.

The co-op slot is the slot that `StellarCoopSlot.txt`, in the same folder as the saves, names. The file holds one line,
the slot's file name (for example `StellarBladeSave04.sav`), saved as UTF-8. Blank lines and lines starting with `#`
are ignored.

**To make it**, follow [INSTALL.md: Co-op save slot](../INSTALL.md#co-op-save-slot): a manual copy on Windows, or
`tools/save_guard.py slot` on Linux. The `slot` command:

- copies main slot SOURCE (0 to 4) onto free slot TARGET and names TARGET in `StellarCoopSlot.txt`;
- checks first that SOURCE passes the game's own load check (header and CRC-32), and refuses an occupied TARGET that
  is not already the co-op slot, so it never overwrites one of your own saves;
- refuses unless the save folder holds exactly one Steam ID folder, and while `StellarCoopSlot.txt` names another
  slot or no valid slot;
- makes its own safety backup, then writes the marker, then the copy, each through a temporary file and a rename;
- writes nothing with `--dry-run`, and needs `--yes` to replace the co-op slot with a new copy.

**To check it**, load the copy with Load Game. `coop status` (or the `[StellarCoop] link: slot=...` line in
`UE4SS.log`) must show `slot=coop index=N marker=N`, where N is the copy's number:

| Line | Meaning |
| --- | --- |
| `slot=coop index=4 marker=4` | The co-op slot is loaded |
| `slot=main index=0 marker=4` | Another slot is loaded (here file 00) |
| `marker=none` | No `StellarCoopSlot.txt` in that folder, often because it is named `StellarCoopSlot.txt.txt` |
| `marker=bad` | The file's text or encoding is wrong: one line with the name, saved as UTF-8 |
| `slot=none` | No save is loaded yet (the title screen) |
| `slot=unknown`, `index=?` or `marker=?` | Not read yet, another game build, or after `coop off` |

## Recovery

The full steps are in [INSTALL.md: Recovery](../INSTALL.md#recovery). In short:

- The mod never writes your own saves, and nothing is ever copied back from the co-op slot.
- To stop using the co-op slot, close the game and move `StellarCoopSlot.txt` out of the folder. The copy then counts
  as an ordinary save.
- If you restore an older backup by hand, move `StellarCoopSlot.txt` out first: otherwise it may name one of your own
  saves. `save_guard.py restore` does this for you.
- Continue loads whichever slot you played last. Load Game is clearer, and `coop status` says which slot is loaded.
- New Game and New Game+ ask which slot to overwrite: that is the game's own behaviour.
- After a Night Operation preview, kill the game instead of quitting from the menu (which saves), then check and
  restore your backup. See [night-operation.md](night-operation.md#after-a-preview-run).
