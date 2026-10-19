# Saves and save safety

The step-by-step procedures for players are in [INSTALL.md](../INSTALL.md#saves-and-steam-cloud).

## What the mod reads and writes

- The mod never reads or writes a save, the inventory, unlocks or equipment.
- Apart from enemy stats with the experimental shared enemies (`coop fight`, off by default), nothing is copied between
  the two players' games. The ghost is display only: a plain actor that is not a Pawn, so lock-on, AI and saves skip it,
  and nothing of it is written to a save. The meshes it loads are only loaded into memory; nothing is worn or unlocked.
- In the save folder, the mod reads only the co-op marker `StellarCoopSlot.txt` (every 5 s), which names the co-op
  save slot.
- Every 5 s the native part also lists the names, sizes and write times of the files in the save folder, without
  opening any save, and logs each change in `coop-link.log`. `coop report` sums the changes up. This log shows when
  the game itself writes its saves.
- On the pinned game build only, and until `coop off`, the mod reads which slot the game entered (every 250 ms), for
  the `slot=` line of `coop status`.

Apart from a restore, which puts a backup back, the only save anything in this project writes is the co-op slot's
copy. `tools/save_guard.py slot` makes it, with the game closed and after a safety backup. Nothing is copied back from
it.

## Where the saves are

- Windows: `%LOCALAPPDATA%\SB\Saved\SaveGames\<your Steam ID>\`
- Linux (Proton): `<Steam library>/steamapps/compatdata/3489700/pfx/drive_c/users/steamuser/AppData/Local/SB/Saved/SaveGames/<your Steam ID>/`

The game has five save slots: the files `StellarBladeSave00.sav` to `StellarBladeSave04.sav`.

## Backups

Back up the saves before you play with any mod, and always before a Night Operation preview or a new look.

On Windows, with the game closed, copy the whole `SaveGames` folder to a place outside the game and Steam folders (see
[INSTALL.md](../INSTALL.md#saves-and-steam-cloud)).

On Linux, use `tools/save_guard.py`, which comes with the repository (not with the release zip). It refuses to run
while the game runs.

| Command | What it does |
| --- | --- |
| `python3 tools/save_guard.py backup` | Copies the whole `SaveGames` folder into `~/StellarBlade-save-backups/<UTC time>/`, with a `SHA256SUMS.txt` |
| `python3 tools/save_guard.py check [--from BACKUP]` | Lists files added, removed or changed since a backup (the latest by default); exit code 0 if none, 1 if any |
| `python3 tools/save_guard.py restore BACKUP --yes` | Copies a backup back over the saves, after a safety backup of the current ones |
| `python3 tools/save_guard.py slot SOURCE TARGET` | Makes the co-op save slot (see below) |

`--saves <folder>` sets your `SaveGames` folder (the default points at one particular Steam library; see `--help`), and
`--to <folder>` sets the backup folder. Backups must be outside the game, its Proton prefix and the save folder.

- A save folder that is missing (a mistyped path, an unmounted drive) or that holds symbolic links is refused. It is
  never read as "every save removed".
- `restore` needs `--yes` and checks the backup against its `SHA256SUMS.txt` first. It then makes a safety backup of
  the current saves. It never deletes a save: a file that is not in the backup stays in place, and `restore` reports
  it. If the backup is older than the co-op slot, `restore` removes `StellarCoopSlot.txt` (a copy is in the safety
  backup) and reports it, so the slot the marker named is an ordinary slot again.
- Exit code 2 means an error. Exit code 1 is reserved for "check found changes".

## Steam Cloud

Steam Cloud syncs the save folder. If a save looks wrong, do not start the game again. First turn Steam Cloud off
for Stellar Blade (right-click the game, Properties, General), so the bad save does not replace the good copy in the
cloud. Then restore your backup.

Keep Steam Cloud off during Night Operation preview runs and while you test new features.

Steam Cloud syncs the co-op slot's `.sav` copy but not `StellarCoopSlot.txt`. On another PC the copy counts as an
ordinary save, and the previews refuse to run there.

## The co-op save slot

Some features run only on a copy of your save, the co-op save slot, and never on your own slots: the two Night Operation
previews (`coop no` and `coop recruiter`) and the experimental shared enemies (`coop fight`). The ghost, the keys and
the Steam link work on any save. Nothing is copied back from the co-op slot to your own slots.

The co-op slot is the slot named in `StellarCoopSlot.txt`, which sits in the same folder as the saves. The file holds
one line, the slot's file name (for example `StellarBladeSave04.sav`), saved as UTF-8. Blank lines and lines starting
with `#` are ignored.

To make the co-op slot, follow [INSTALL.md: Co-op save slot](../INSTALL.md#co-op-save-slot): a manual copy on Windows,
or `tools/save_guard.py slot` on Linux. The `slot` command:

- copies main slot SOURCE (0 to 4) onto free slot TARGET and names TARGET in `StellarCoopSlot.txt`;
- checks first that SOURCE passes the game's load check (header and CRC-32), and refuses an occupied TARGET that is
  not already the co-op slot, so it never overwrites one of your own saves;
- refuses unless the save folder holds exactly one Steam ID folder, and while `StellarCoopSlot.txt` names another
  slot or no valid slot;
- makes its own safety backup, then writes the marker, then the copy, each through a temporary file and a rename;
- writes nothing with `--dry-run`, and needs `--yes` to replace the co-op slot with a new copy.

To check the co-op slot, load the copy with Load Game. `coop status` (or the `[StellarCoop] link: slot=...` line in
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

The full steps are in [INSTALL.md: Recovery](../INSTALL.md#recovery).

- To stop using the co-op slot, close the game and move `StellarCoopSlot.txt` out of the folder. The copy then counts
  as an ordinary save.
- If you restore an older backup by hand, move `StellarCoopSlot.txt` out first. Otherwise it may name one of your own
  saves. `save_guard.py restore` does this itself.
- Continue loads whichever slot you played last. Use Load Game to pick the slot; `coop status` shows which slot is
  loaded.
- New Game and New Game+ ask which slot to overwrite. That prompt comes from the game, not from the mod.
- After a Night Operation preview, kill the game instead of quitting from the menu (which saves), then check and
  restore your backup. See [night-operation.md](night-operation.md#after-a-preview-run).
