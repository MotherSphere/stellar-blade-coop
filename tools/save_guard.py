#!/usr/bin/env python3
"""Backs up, checks and restores Stellar Blade's SaveGames folder, and makes the co-op save slot (never while the game
runs, never deletes a save)."""
import argparse
import hashlib
import os
import shutil
import sys
import time
import zlib
from pathlib import Path

from install import GAME, running_game

PREFIX = Path('/mnt/Jeux/SteamLibrary/steamapps/compatdata/3489700/pfx')
SAVES = PREFIX / 'drive_c/users/steamuser/AppData/Local/SB/Saved/SaveGames'
BACKUPS = Path.home() / 'StellarBlade-save-backups'
SUMS = 'SHA256SUMS.txt'  # Paths relative to the backup folder, so `sha256sum -c SHA256SUMS.txt` works there too.
MARKER = 'StellarCoopSlot.txt'  # In SaveGames/<steamid>/: names the co-op slot; the native part reads it too.


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


def slot_file(n):
    return f'StellarBladeSave{n:02d}.sav'  # The game lists files 00-04 only (SaveSlotMaxCount 5).


def marked(data):
    """The slot (0-4) a StellarCoopSlot.txt names, or None. Same grammar as the native slot::marker: one name line, ASCII
    case ignored, '#' and blank lines dropped; bytes, so UTF-16 Notepad output (NUL bytes) never matches."""
    if len(data) > 4096: return None
    lines = [line.strip(b' \t\r') for line in data.removeprefix(b'\xef\xbb\xbf').split(b'\n')]
    lines = [line for line in lines if line and not line.startswith(b'#')]
    names = {slot_file(n).lower().encode(): n for n in range(5)}
    return names.get(lines[0].lower()) if len(lines) == 1 else None


def game_save(data):
    """The game's own load check: EVAS, version 1, a GVAS body, then the little-endian zlib CRC-32 of bytes [8, -4)."""
    return (len(data) >= 16 and data[:4] == b'EVAS' and data[4] == 1 and data[8:12] == b'GVAS' and
            zlib.crc32(data[8:-4]) == int.from_bytes(data[-4:], 'little'))


def put(path, data):
    """Writes through <name>.coop-tmp and a rename: an interrupted run never leaves a partial file under path's name
    (and Steam Cloud never syncs a name that does not end in .sav)."""
    tmp = path.with_name(path.name + '.coop-tmp')
    tmp.write_bytes(data)
    os.replace(tmp, path)


def make_slot(args):
    """Copies slot SOURCE onto slot TARGET of the one account and marks TARGET the co-op slot (D2: never merged back).
    The checks come first, so a refusal writes nothing; then the safety backup, the marker, and the copy last: a failed
    run leaves a marker naming an absent file (run slot again) or the previous co-op copy whole, never a partial .sav."""
    if args.source == args.target: fail('source and target are the same slot')
    ids = [p for p in args.saves.iterdir() if p.is_dir() and p.name.isascii() and p.name.isdigit()]
    if len(ids) != 1: fail(f'{len(ids)} Steam ID folders in {args.saves}: expected exactly one')
    account = ids[0]
    src, dst, marker = account / slot_file(args.source), account / slot_file(args.target), account / MARKER
    coop = None
    if marker.exists():
        coop = marked(marker.read_bytes())
        if coop is None: fail(f'{account.name}/{MARKER} names no slot StellarBladeSave00.sav to 04.sav: fix it or move '
                              'it out, with the game closed')
        if coop != args.target:  # So the co-op slot is never a source onto a main slot.
            fail(f'{slot_file(coop)} is the co-op slot: only it can be replaced (move {MARKER} out first to start '
                 'another)')
    if not src.is_file(): fail(f'No {src.name} in {account}')
    data = src.read_bytes()
    if not game_save(data): fail(f"{src.name} fails the game's own check (EVAS header, CRC-32): not copying it")
    if dst.exists() and coop != args.target:
        fail(f'{dst.name} holds a main save: move it out of {account}, with the game closed, to free the slot')
    if dst.exists() and not args.yes:
        fail(f'{dst.name} is the co-op slot: add --yes to replace it with a new copy of {src.name}')
    if args.dry_run:
        print(f'Dry run: would back up {args.saves} into {args.to}, mark {dst.name} in {MARKER}, then copy {src.name} '
              f'({len(data)} bytes, CRC-32 ok) onto it')
        return 0
    safety = backup(args.saves, args.to)
    if running_game(): fail(f'Stellar Blade started during the backup: nothing written ({safety})')  # It may be saving.
    stamp = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    put(marker, (f'{dst.name}\n'
                 "# StellarCoop's co-op save slot for this Steam account: coop no (and later shared features) run only "
                 'on it.\n'
                 f'# Copied from {src.name} at {stamp} by tools/save_guard.py. Never copied back to a main slot.\n'
                 '# To make it a main slot again: close the game, then move this file out of this folder.\n').encode())
    put(dst, data)
    if hashlib.sha256(dst.read_bytes()).digest() != hashlib.sha256(data).digest():
        fail(f'the copy does not match {src.name}: run slot again with --yes, or restore {safety.name}')
    print(f'Copied {src.name} onto {dst.name} in {account.name} and marked it the co-op slot ({MARKER}). Load it with '
          f'Load Game; coop status then shows slot=coop index={args.target} marker={args.target}.')
    return 0


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
    make = sub.add_parser('slot', help='Copy slot SOURCE onto free slot TARGET, marked the co-op slot, after a backup')
    make.add_argument('source', type=int, choices=range(5), metavar='SOURCE', help='N of StellarBladeSave0N.sav, 0-4')
    make.add_argument('target', type=int, choices=range(5), metavar='TARGET', help='A free slot, or the co-op slot')
    make.add_argument('--yes', action='store_true', help='Required to replace the co-op slot with a new copy')
    make.add_argument('--dry-run', action='store_true', help='Run every check, say what would be done, write nothing')
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
    if args.command == 'slot': return make_slot(args)
    if not args.yes: fail('restore overwrites the current saves: add --yes to confirm')
    source = args.to / args.source
    old = recorded(source)
    if hashes(source / 'SaveGames') != old: fail(f'{source} no longer matches its {SUMS}: not restoring from it')
    safety = backup(args.saves, args.to)
    print(f'Safety backup of the current saves: {safety}')
    # A backup from before `slot` puts a main save back under a marker that "Left in place" would keep, and coop no
    # would then run on a main save (N9). The marker is no save, and its copy is in the safety backup. Every marker goes
    # before the copy, so a partial restore leaves none (fails closed); the copy puts back one the backup has.
    for marker in args.saves.glob(f'*/{MARKER}'):
        rel = marker.relative_to(args.saves).as_posix()
        marker.unlink()
        if rel not in old:
            print(f'Removed {rel}, which the backup does not have (a copy is in {safety.name}): the slot it named is a '
                  'main slot again')
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
