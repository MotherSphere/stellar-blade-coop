#!/usr/bin/env python3
"""tools/save_guard.py round trip on a fake save folder in a temporary directory. Run: python3 tests/save_guard_test.py"""
import contextlib
import io
import os
import sys
import tempfile
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

print('save_guard_test: ok')
