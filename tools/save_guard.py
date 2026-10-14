#!/usr/bin/env python3
"""Backs up, checks and restores Stellar Blade's SaveGames folder (never while the game runs, never deletes a save)."""
import argparse
import hashlib
import shutil
import sys
import time
from pathlib import Path

from install import GAME, running_game

PREFIX = Path('/mnt/Jeux/SteamLibrary/steamapps/compatdata/3489700/pfx')
SAVES = PREFIX / 'drive_c/users/steamuser/AppData/Local/SB/Saved/SaveGames'
BACKUPS = Path.home() / 'StellarBlade-save-backups'
SUMS = 'SHA256SUMS.txt'  # Paths relative to the backup folder, so `sha256sum -c SHA256SUMS.txt` works there too.


def fail(message):
    print(f'save_guard: {message}', file=sys.stderr)
    sys.exit(2)  # 1 is reserved for "check found changes".


def hashes(folder):
    """{path relative to folder: SHA-256} of every file under it."""
    return {p.relative_to(folder).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(folder.rglob('*')) if p.is_file()}


def recorded(backup):
    """The hashes a backup recorded when it was made, relative to the SaveGames folder."""
    if not (backup / SUMS).is_file(): fail(f'{backup} is not a complete backup (no {SUMS})')
    lines = (backup / SUMS).read_text().splitlines()
    return {rel.removeprefix('SaveGames/'): digest for digest, rel in (line.split('  ', 1) for line in lines)}


def backup(saves, root):
    if not saves.is_dir(): fail(f'No save folder at {saves}')
    stamp = time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())
    dest, n = root / stamp, 1
    while dest.exists():  # Two backups in the same second (restore's safety backup).
        n += 1
        dest = root / f'{stamp}-{n}'
    shutil.copytree(saves, dest / 'SaveGames')  # copy2: contents and modification times.
    sums = hashes(dest / 'SaveGames')
    (dest / SUMS).write_text(''.join(f'{digest}  SaveGames/{rel}\n' for rel, digest in sums.items()))  # Written last.
    print(f'Backed up {len(sums)} files into {dest}')
    return dest


def differences(saves, old):
    now = hashes(saves) if saves.is_dir() else {}
    return ([f'added    {rel}' for rel in now if rel not in old] +
            [f'removed  {rel}' for rel in old if rel not in now] +
            [f'changed  {rel}' for rel in now if rel in old and now[rel] != old[rel]])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--saves', type=Path, default=SAVES, help='SaveGames folder (default: %(default)s)')
    parser.add_argument('--to', type=Path, default=BACKUPS, help='Folder of backups (default: %(default)s)')
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('backup', help='Copy the whole SaveGames folder into <--to>/<UTC time>/, with SHA256SUMS.txt')
    check = sub.add_parser('check', help='List files added, removed or changed since a backup: exit 0 if none, 1 if any')
    check.add_argument('--from', dest='source', metavar='BACKUP', help='Backup name or path (default: the latest)')
    restore = sub.add_parser('restore', help='Copy a backup back over the saves, after a safety backup of them')
    restore.add_argument('source', metavar='BACKUP', help='Backup name or path')
    restore.add_argument('--yes', action='store_true', help='Required: restore overwrites the current saves')
    args = parser.parse_args(argv)
    if running_game(): fail('Close Stellar Blade first: its saves must not change under it.')
    if any(args.to.resolve().is_relative_to(p.resolve()) for p in (args.saves, PREFIX.parent, GAME)):
        fail(f'Backups must live outside the game, its Proton prefix and the save folder, not in {args.to}')
    # Every command: a mistyped --saves or an unmounted drive is refused, never read as "every save removed" or written
    # to; symbolic links are refused, so backup, check and restore all see the same files.
    if not args.saves.is_dir(): fail(f'No save folder at {args.saves}')
    if any(p.is_symlink() for p in args.saves.rglob('*')): fail(f'Symbolic links in {args.saves}: not touching them')
    if args.command == 'backup':
        backup(args.saves, args.to)
        return 0
    if args.command == 'check':
        if args.source: source = args.to / args.source  # An absolute path replaces --to.
        else:
            complete = [p for p in args.to.glob('*') if (p / SUMS).is_file()]
            if not complete: fail(f'No backup in {args.to}')
            source = max(complete, key=lambda p: p.name)
        changes = differences(args.saves, recorded(source))
        for line in changes: print(line)
        print(f'{len(changes)} difference(s) from {source}')
        return 1 if changes else 0
    if not args.yes: fail('restore overwrites the current saves: add --yes to confirm')
    source = args.to / args.source
    old = recorded(source)
    if hashes(source / 'SaveGames') != old: fail(f'{source} no longer matches its {SUMS}: not restoring from it')
    safety = backup(args.saves, args.to)
    print(f'Safety backup of the current saves: {safety}')
    try:
        for rel in old:
            (args.saves / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / 'SaveGames' / rel, args.saves / rel)
    except OSError as error:
        fail(f'partial restore ({error}): fix the cause and run restore again, or restore {safety.name} to undo it')
    after = differences(args.saves, old)
    for line in after:
        if line.startswith('added'): print(f'Left in place, not in the backup: {line.split(maxsplit=1)[1]}')
        else: fail(f'restore did not reproduce the backup ({line}): check the saves')  # Never deletes a save.
    print(f'Restored {len(old)} files from {source}')
    return 0


if __name__ == '__main__':
    try: sys.exit(main())
    except (OSError, ValueError) as error: fail(error)  # Exit 2, never 1 ("saves changed"); shutil.Error is an OSError.
