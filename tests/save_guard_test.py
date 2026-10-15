#!/usr/bin/env python3
"""tools/save_guard.py round trip and co-op slot on fake save folders in temporary directories.
Run: python3 tests/save_guard_test.py"""
import contextlib
import io
import os
import re
import sys
import tempfile
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import save_guard  # noqa: E402

save_guard.running_game = lambda: False  # The real check would fail this test while Stellar Blade runs.


def run(*argv):
    """(exit code, stdout + stderr) of save_guard with these arguments."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        try:
            code = save_guard.main([str(a) for a in argv])
        except SystemExit as stop:
            code = stop.code
    return code, out.getvalue()


with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    saves, to = tmp / 'SaveGames', tmp / 'backups'
    slot = saves / '76561198000000000/StellarBladeSave00.sav'
    slot.parent.mkdir(parents=True)
    slot.write_bytes(b'slot zero')
    (saves / 'steam_autocloud.vdf').write_text('cloud')
    os.utime(slot, (1_000_000, 1_000_000))
    opt = ['--saves', saves, '--to', to]

    # No backup yet: check is an error (2), not "changed" (1).
    assert run(*opt, 'check')[0] == 2

    code, out = run(*opt, 'backup')
    assert code == 0, out
    first = next(to.iterdir())
    sums = (first / 'SHA256SUMS.txt').read_text()
    assert 'SaveGames/76561198000000000/StellarBladeSave00.sav' in sums and 'SaveGames/steam_autocloud.vdf' in sums
    assert (first / 'SaveGames/76561198000000000/StellarBladeSave00.sav').stat().st_mtime == 1_000_000
    assert run(*opt, 'check') == (0, f'0 difference(s) from {first}\n')

    # The game writes a slot, adds one and drops the cloud file.
    slot.write_bytes(b'slot zero, played')
    new = saves / '76561198000000000/StellarBladeSave01.sav'
    new.write_bytes(b'slot one')
    (saves / 'steam_autocloud.vdf').unlink()
    code, out = run(*opt, 'check')
    assert code == 1, out
    assert 'changed  76561198000000000/StellarBladeSave00.sav' in out
    assert 'added    76561198000000000/StellarBladeSave01.sav' in out
    assert 'removed  steam_autocloud.vdf' in out

    # Restore refuses without --yes, and changes nothing.
    code, out = run(*opt, 'restore', first.name)
    assert code == 2 and '--yes' in out
    assert slot.read_bytes() == b'slot zero, played' and len(list(to.iterdir())) == 1

    # Refuses while the game runs, whatever the command.
    save_guard.running_game = lambda: True
    for command in (['backup'], ['check'], ['restore', first.name, '--yes']):
        assert run(*opt, *command)[0] == 2
    save_guard.running_game = lambda: False

    # Refuses to keep backups inside the save folder (copytree would copy into itself).
    assert run('--saves', saves, '--to', saves / 'b', 'backup')[0] == 2 and not (saves / 'b').exists()

    code, out = run(*opt, 'restore', first.name, '--yes')
    assert code == 0, out
    assert slot.read_bytes() == b'slot zero' and slot.stat().st_mtime == 1_000_000
    assert (saves / 'steam_autocloud.vdf').read_text() == 'cloud'
    assert new.read_bytes() == b'slot one' and 'Left in place' in out  # Never deletes a save.
    code, out = run(*opt, 'check', '--from', first.name)
    assert code == 1 and out.splitlines()[0] == 'added    76561198000000000/StellarBladeSave01.sav', out

    # The safety backup holds the state before the restore, and is now the latest one.
    safety = max(p for p in to.iterdir() if p != first)
    assert (safety / 'SaveGames/76561198000000000/StellarBladeSave00.sav').read_bytes() == b'slot zero, played'
    new.unlink()
    assert run(*opt, 'check', '--from', first)[0] == 0  # A path works as well as a name.
    assert run(*opt, 'check')[0] == 1  # Latest = safety backup, which differs.

    # A damaged backup is refused before anything is touched.
    (first / 'SaveGames/76561198000000000/StellarBladeSave00.sav').write_bytes(b'bit rot')
    slot.write_bytes(b'keep me')
    code, out = run(*opt, 'restore', first.name, '--yes')
    assert code == 2 and 'no longer matches' in out and slot.read_bytes() == b'keep me'

    # A mistyped --saves (or an unmounted drive) is refused, and nothing is created there.
    absent = tmp / 'absent'
    healthy = sorted(p for p in to.iterdir() if (p / 'SHA256SUMS.txt').exists())[-1]
    code, out = run('--saves', absent, '--to', to, 'restore', healthy.name, '--yes')
    assert code == 2 and not absent.exists(), out

    # check with a missing folder is an error (2), never "every save removed" (1); symlinks are refused everywhere.
    assert run('--saves', tmp / 'absent', '--to', to, 'check')[0] == 2
    (saves / 'link.sav').symlink_to(slot)
    for command in (['backup'], ['check']):
        code, out = run(*opt, *command)
        assert code == 2 and 'Symbolic links' in out, (command, out)
    (saves / 'link.sav').unlink()


def save(body, head=b'EVAS\x01\0\0\0', magic=b'GVAS'):
    """A file that passes the game's own check: EVAS, version 1, GVAS, the body, then CRC-32 [8, -4) little-endian."""
    return head + magic + body + zlib.crc32(magic + body).to_bytes(4, 'little')


# 12. The marker grammar: the same table as the native slot::marker test, plus tabs and the 4096-byte edge (case 3
# checks that the tool writes TOOL_TEXT).
TOOL_TEXT = b'''StellarBladeSave04.sav
# StellarCoop's co-op save slot for this Steam account: coop no (and later shared features) run only on it.
# Copied from StellarBladeSave00.sav at 2026-10-15T20:01:02Z by tools/save_guard.py. Never copied back to a main slot.
# To make it a main slot again: close the game, then move this file out of this folder.
'''
MARKS = [(b'StellarBladeSave04.sav\n', 4), (b'\xef\xbb\xbfStellarBladeSave04.sav\r\n', 4),
         (b'# c\n\n  stellarbladesave02.SAV \r\n', 2), (b'StellarBladeSave00.sav', 0), (TOOL_TEXT, 4),
         (b'\tStellarBladeSave03.sav\t', 3),
         (b'', None), (b'# only\n', None), (b'StellarBladeSave05.sav', None), (b'StellarBladeSave4.sav', None),
         (b'file=StellarBladeSave04.sav', None), (b'StellarBladeSave04.sav.txt', None),
         (b'StellarBladeSave04.sav\nStellarBladeSave03.sav', None), (b'x\nStellarBladeSave04.sav', None),
         (b'\xff\xfe' + 'StellarBladeSave04.sav'.encode('utf-16-le'), None),
         (b'StellarBladeSave04.sav\n#'.ljust(4096, b'#'), 4), (b'StellarBladeSave04.sav\n#'.ljust(4097, b'#'), None)]
for data, expected in MARKS:
    assert save_guard.marked(data) == expected, (data[:40], expected)

# The game's own check: each part on its own.
good = save(b'body')
assert save_guard.game_save(good)
for bad in (b'EVAX' + good[4:], good[:4] + b'\x02' + good[5:], good[:-1] + bytes([good[-1] ^ 1]),
            save(b'body', magic=b'GVAX'), b'EVAS'):
    assert not save_guard.game_save(bad), bad

with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    saves, to = tmp / 'SaveGames', tmp / 'backups'
    account = saves / '76561198000000000'
    (account / 'Backup').mkdir(parents=True)
    file = {n: account / save_guard.slot_file(n) for n in range(5)}
    for n in (0, 1, 3, 4): file[n].write_bytes(save(b'slot %d' % n))
    (account / 'Backup/StellarBladeSave00_Old.sav').write_bytes(save(b'slot 0, before'))
    (account / 'steam_autocloud.vdf').write_text('cloud')
    (saves / 'steam_autocloud.vdf').write_text('cloud')
    marker = account / save_guard.MARKER
    opt = ['--saves', saves, '--to', to]
    tree = lambda: save_guard.hashes(saves)  # noqa: E731
    backups = lambda: sorted(to.iterdir()) if to.exists() else []  # noqa: E731
    rel = lambda path: path.relative_to(saves).as_posix()  # noqa: E731

    # 1. An occupied, unmarked target is a main save: refused, before any backup, by a dry run too.
    before = tree()
    for dry in ([], ['--dry-run']):
        code, out = run(*opt, 'slot', 0, 4, *dry)
        assert code == 2 and 'StellarBladeSave04.sav holds a main save: move it out of' in out, (dry, out)
    assert tree() == before and backups() == []

    # 2. With slot 4 freed by hand, a dry run says what it would do and writes nothing.
    file[4].rename(tmp / 'freed-04.sav')
    before = tree()
    code, out = run(*opt, 'slot', 0, 4, '--dry-run')
    assert code == 0 and out == (f'Dry run: would back up {saves} into {to}, mark StellarBladeSave04.sav in '
                                 f'StellarCoopSlot.txt, then copy StellarBladeSave00.sav ({file[0].stat().st_size} '
                                 'bytes, CRC-32 ok) onto it\n'), out
    assert tree() == before and backups() == []

    # 3. The copy: marker and Save04 added, nothing else changed, one backup taken before them, no temporary file left.
    code, out = run(*opt, 'slot', 0, 4)
    assert code == 0 and out.endswith('Copied StellarBladeSave00.sav onto StellarBladeSave04.sav in 76561198000000000 '
                                      'and marked it the co-op slot (StellarCoopSlot.txt). Load it with Load Game; coop '
                                      'status then shows slot=coop index=4 marker=4.\n'), out
    assert file[4].read_bytes() == file[0].read_bytes()
    tool_text = marker.read_bytes()
    assert re.sub(rb' at \S+Z by ', b' at 2026-10-15T20:01:02Z by ', tool_text) == TOOL_TEXT, tool_text
    assert tree() == {**before, rel(marker): tree()[rel(marker)], rel(file[4]): tree()[rel(file[4])]}
    assert not list(saves.rglob('*.coop-tmp'))
    first, = backups()
    assert (first / 'SHA256SUMS.txt').is_file() and not (first / 'SaveGames' / rel(file[4])).exists()
    assert not (first / 'SaveGames' / rel(marker)).exists()

    # 4. Replacing the co-op slot needs --yes; with it, the backup keeps the co-op copy it replaces.
    file[0].write_bytes(save(b'slot 0, played'))
    before = tree()
    for dry in ([], ['--dry-run']):
        code, out = run(*opt, 'slot', 0, 4, *dry)
        assert code == 2 and ('StellarBladeSave04.sav is the co-op slot: add --yes to replace it with a new copy of '
                              'StellarBladeSave00.sav') in out, (dry, out)
    assert tree() == before and len(backups()) == 1
    code, out = run(*opt, 'slot', 0, 4, '--yes')
    assert code == 0 and file[4].read_bytes() == save(b'slot 0, played'), out
    second, = set(backups()) - {first}
    assert (second / 'SaveGames' / rel(file[4])).read_bytes() == save(b'slot 0')

    # 5. No merge-back: while a marker exists, every other target is refused, the free slot 2 too.
    before, count = tree(), len(backups())
    for source, target in ((0, 3), (4, 1), (4, 2)):
        code, out = run(*opt, 'slot', source, target)
        assert code == 2 and ('StellarBladeSave04.sav is the co-op slot: only it can be replaced (move '
                              'StellarCoopSlot.txt out first to start another)') in out, (source, target, out)
    assert tree() == before and len(backups()) == count and not file[2].exists()

    # 6. The same slot, and a slot the game never lists.
    code, out = run(*opt, 'slot', 4, 4, '--yes')
    assert code == 2 and 'source and target are the same slot' in out, out
    code, out = run(*opt, 'slot', 0, 5)
    assert code == 2 and 'invalid choice' in out, out
    assert tree() == before and len(backups()) == count

    # 7. A source that fails the game's CRC is never copied.
    played = file[0].read_bytes()
    file[0].write_bytes(played[:-5] + bytes([played[-5] ^ 1]) + played[-4:])
    before = tree()
    for dry in ([], ['--dry-run']):
        code, out = run(*opt, 'slot', 0, 4, '--yes', *dry)
        assert code == 2 and ("StellarBladeSave00.sav fails the game's own check (EVAS header, CRC-32): not copying "
                              'it') in out, (dry, out)
    assert tree() == before and len(backups()) == count
    file[0].write_bytes(played)

    # 8. A marker that names no slot is refused, not read as "no marker".
    marker.write_bytes(b'StellarBladeSave05.sav\n')
    before = tree()
    code, out = run(*opt, 'slot', 0, 4, '--yes')
    assert code == 2 and ('76561198000000000/StellarCoopSlot.txt names no slot StellarBladeSave00.sav to 04.sav: fix '
                          'it or move it out, with the game closed') in out, out
    assert tree() == before and len(backups()) == count
    marker.write_bytes(tool_text)

    # 9. Two Steam accounts: which one is meant is unknown, so refused.
    (saves / '76561198000000001').mkdir()
    before = tree()
    code, out = run(*opt, 'slot', 0, 4, '--yes')
    assert code == 2 and f'2 Steam ID folders in {saves}: expected exactly one' in out, out
    assert tree() == before and len(backups()) == count
    (saves / '76561198000000001').rmdir()

    # 10. The game running: refused before anything, and again after the backup, before the marker and the copy.
    marker.rename(tmp / 'marker-aside')
    file[4].rename(tmp / 'coop-aside.sav')
    before = tree()
    save_guard.running_game = lambda: True
    assert run(*opt, 'slot', 0, 4)[0] == 2 and tree() == before and len(backups()) == count
    answers = iter([False, True])
    save_guard.running_game = lambda: next(answers)
    code, out = run(*opt, 'slot', 0, 4)
    assert code == 2 and 'Stellar Blade started during the backup: nothing written' in out, out
    assert not marker.exists() and not file[4].exists() and tree() == before and len(backups()) == count + 1
    save_guard.running_game = lambda: False

    # 11. Interrupted at the copy's rename: the marker names an absent file, and running slot again (no --yes) works.
    replace = save_guard.os.replace
    def broken(src, dst):
        if str(dst).endswith('.sav'): raise OSError('interrupted')
        replace(src, dst)
    save_guard.os.replace = broken
    try:
        run(*opt, 'slot', 0, 4)
        raise AssertionError('the interrupted copy did not fail')
    except OSError: pass
    finally: save_guard.os.replace = replace
    assert save_guard.marked(marker.read_bytes()) == 4 and not file[4].exists()
    code, out = run(*opt, 'slot', 0, 4)
    assert code == 0 and file[4].read_bytes() == file[0].read_bytes() and not list(saves.rglob('*.coop-tmp')), out

    # 13. Restoring a backup from before the slot removes the marker (its copy goes into the safety backup); restoring
    # one that has the marker keeps it.
    before = set(backups())
    code, out = run(*opt, 'restore', first.name, '--yes')
    safety, = set(backups()) - before
    assert code == 0 and (f'Removed 76561198000000000/StellarCoopSlot.txt, which the backup does not have (a copy is '
                          f'in {safety.name}): the slot it named is a main slot again') in out, out
    assert not marker.exists() and (safety / 'SaveGames' / rel(marker)).is_file()
    assert 'Left in place, not in the backup: 76561198000000000/StellarBladeSave04.sav' in out  # Never deletes a save.
    code, out = run(*opt, 'restore', safety.name, '--yes')
    assert code == 0 and 'Removed' not in out, out
    assert marker.read_bytes() == (safety / 'SaveGames' / rel(marker)).read_bytes()
    # A restore that fails partway (here at the last file, the root steam_autocloud.vdf) leaves no marker: the main
    # saves it already copied back are never left under one.
    (saves / 'steam_autocloud.vdf').chmod(0o444)
    code, out = run(*opt, 'restore', first.name, '--yes')
    (saves / 'steam_autocloud.vdf').chmod(0o644)
    assert code == 2 and 'partial restore' in out and not marker.exists(), out

    # 14. Symbolic links are refused for slot too.
    (account / 'link.sav').symlink_to(file[0])
    before = tree()
    code, out = run(*opt, 'slot', 0, 4, '--yes')
    assert code == 2 and 'Symbolic links' in out and tree() == before, out
    (account / 'link.sav').unlink()

print('save_guard_test: ok')
