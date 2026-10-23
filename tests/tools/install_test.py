#!/usr/bin/env python3
"""tools/install.py backup, install, uninstall and the release zip on a fake game folder in a temporary directory.
Run: python3 tests/tools/install_test.py"""
import contextlib
import hashlib
import io
import re
import shutil
import signal
import sys
import tempfile
import time
import types
import zipfile
from fnmatch import fnmatch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import install  # noqa: E402

install.running_game = lambda: False  # The real check would fail this test while Stellar Blade runs.
SAVES_LINE = 'Saves, the co-op copies and StellarCoopSlot.txt are never touched (INSTALL.md: Co-op saves).\n'
CLOSE = 'Close Stellar Blade first: its mods must not change under it.'


def run(fn, *args):
    """(exit code or sys.exit message, stdout + stderr) of fn(*args)."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        try:
            code = fn(*args)
        except SystemExit as stop:
            code = stop.code
    return code, out.getvalue()


def uninstall(*extra):
    # Never main() without --uninstall: the install path runs every test, this one included.
    return run(install.main, ['--uninstall', *extra, '--game', str(install.GAME)])


with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    assert not tmp.resolve().is_relative_to('/mnt')  # Never the real game folder.
    install.GAME, install.BACKUPS = tmp / 'game', tmp / 'backups'
    mods = install.GAME / 'SB/Binaries/Win64/ue4ss/Mods'
    target = mods / 'StellarCoop'
    mods.mkdir(parents=True)

    def tree():
        """Every path under the temporary root: a file's bytes, else whether it is a link."""
        return {p.relative_to(tmp).as_posix(): p.read_bytes() if p.is_file() else p.is_symlink()
                for p in sorted(tmp.rglob('*'))}

    def backups():
        return sorted(install.BACKUPS.iterdir()) if install.BACKUPS.exists() else []

    def files_of(root):
        return {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob('*') if p.is_file()}

    # 1. A fresh install writes the files and a manifest equal to them, and backs up nothing.
    v1 = {'enabled.txt': b'', 'Scripts/main.lua': b'main', 'Scripts/old.lua': b'old', 'StellarCoop.dll': b'dll 1'}
    code, out = run(install.install_files, target, v1)
    assert code is None and out == f'Installed 4 files into {target}\n', out
    manifest = (target / install.MANIFEST).read_bytes()
    assert manifest.decode().splitlines() == sorted(v1)
    assert files_of(target) == {**v1, install.MANIFEST: manifest} and not backups()

    # 2. A reinstall that drops a file removes it, keeps what the mod wrote in game, and backs up first exactly the
    # files it replaces or removes, the manifest included.
    (target / 'coop-host.log').write_bytes(b'log')
    (target / 'coop-settings.txt').write_bytes(b'send_rate=20\n')
    v2 = {'enabled.txt': b'', 'Scripts/main.lua': b'main 2', 'StellarCoop.dll': b'dll 2'}
    code, out = run(install.install_files, target, v2)
    first, = backups()
    dest = first / 'StellarCoop'
    assert code is None and re.fullmatch(r'\d{8}T\d{6}Z', first.name), out
    assert out == (f'Backed up 5 files into {dest}\nRemoving {target / "Scripts/old.lua"}\n'
                   f'Installed 3 files into {target}\n'), out
    assert files_of(dest) == {**v1, install.MANIFEST: manifest}  # Not the log or the settings.
    assert files_of(target) == {**v2, install.MANIFEST: b''.join(f'{r}\n'.encode() for r in sorted(v2)),
                                'coop-host.log': b'log', 'coop-settings.txt': b'send_rate=20\n'}

    # 3. Two backups within one second get two folders: a later one never overwrites an earlier one.
    clock = install.time
    install.time = types.SimpleNamespace(strftime=time.strftime, gmtime=lambda: time.gmtime(0))
    try:
        a, b = (run(install.backup, target, ['StellarCoop.dll'])[0] for _ in range(2))
    finally: install.time = clock
    assert (a.parent.name, b.parent.name) == ('19700101T000000Z', '19700101T000000Z-1'), (a, b)
    assert (a / 'StellarCoop.dll').read_bytes() == (b / 'StellarCoop.dll').read_bytes() == b'dll 2'
    for made in (a, b): shutil.rmtree(made.parent)

    # 3b. A backup folder that is a link to an unmounted disk fails at once, before install or uninstall changes
    # anything. It once looped forever, so the alarm (default action: kill) turns a hang into a failure.
    backups_root, install.BACKUPS = install.BACKUPS, tmp / 'backups-link'
    install.BACKUPS.symlink_to(tmp / 'unmounted', target_is_directory=True)
    before = tree()
    signal.alarm(10)
    for call in (lambda: install.install_files(target, v1), lambda: install.uninstall(target, False)):
        try:
            call()
            raise AssertionError('no error')
        except FileExistsError as error:
            assert error.filename == str(install.BACKUPS), error
    signal.alarm(0)
    assert tree() == before
    install.BACKUPS.unlink()
    install.BACKUPS = backups_root

    # 4. Refusals while the game runs change nothing, for install and uninstall.
    install.running_game = lambda: True
    before = tree()
    assert run(install.install_files, target, v1) == (CLOSE, '')
    assert uninstall() == (CLOSE, '') and tree() == before
    install.running_game = lambda: False

    # 5. An uninstall dry run changes nothing and says what it would do.
    assert uninstall('--dry-run') == (None, f'Dry run: would back up 6 files into {install.BACKUPS} and remove '
                                            f'{target}\n') and tree() == before

    # 6. An uninstall backs up the whole folder, removes it, leaves mods.txt alone (another mod's line is no reason to
    # name it) and always names the saves.
    (mods / 'mods.txt').write_bytes(b'BPModLoaderMod : 1\n')
    code, out = uninstall()
    dest, = set(p / 'StellarCoop' for p in backups()) - {first / 'StellarCoop'}
    assert code is None and out == f'Backed up 6 files into {dest}\nRemoved {target}\n{SAVES_LINE}', out
    assert not target.exists() and (mods / 'mods.txt').read_bytes() == b'BPModLoaderMod : 1\n'
    assert files_of(dest)['coop-host.log'] == b'log' and files_of(dest)['coop-settings.txt'] == b'send_rate=20\n'
    assert len(files_of(dest)) == 6

    # 7. Nothing left to uninstall: said, and nothing changes.
    before = tree()
    assert uninstall() == (None, f'Nothing to uninstall: no StellarCoop folder at {target}\n') and tree() == before

    # 8. An install after an uninstall works, and has nothing to back up.
    count = len(backups())
    assert run(install.install_files, target, v2) == (None, f'Installed 3 files into {target}\n')
    assert files_of(target) == {**v2, install.MANIFEST: b''.join(f'{r}\n'.encode() for r in sorted(v2))}
    assert len(backups()) == count

    # 9. A StellarCoop line in mods.txt is reported, never edited.
    (mods / 'mods.txt').write_bytes(b'BPModLoaderMod : 1\nStellarCoop : 1\n')
    code, out = uninstall()
    assert code is None and out.endswith(f'Removed {target}\nmods.txt still names StellarCoop: remove that line by '
                                         f'hand ({mods / "mods.txt"})\n{SAVES_LINE}'), out
    assert (mods / 'mods.txt').read_bytes() == b'BPModLoaderMod : 1\nStellarCoop : 1\n'

    # 10. A folder this tool did not install (no manifest, or a link to one) is left alone, even by the dry run.
    left_alone = f'{target} was not installed by this tool (no install-manifest.txt, or a link): left alone'
    target.mkdir()
    (target / 'main.lua').write_bytes(b'by hand')
    before = tree()
    assert uninstall() == (left_alone, '') and uninstall('--dry-run') == (left_alone, '') and tree() == before
    target.rename(tmp / 'checkout')
    (tmp / 'checkout' / install.MANIFEST).write_bytes(b'main.lua\n')
    target.symlink_to(tmp / 'checkout', target_is_directory=True)
    before = tree()
    assert uninstall() == (left_alone, '') and tree() == before

    # 11. The package content check: the shipped files plus the four docs, nothing the mod writes in game, no save
    # and no game file. A stray file in mod/StellarCoop fails here, so it fails the dry run.
    dll = tmp / 'StellarCoop.dll'
    dll.write_bytes(b'dll')
    files = install.package('v', dll)
    shipped = {'enabled.txt', 'StellarCoop.dll', 'INSTALL.md', 'LICENSE', 'CHANGELOG.md', 'SHA256SUMS.txt',
               'Assets/MotherSphere.png',
               *(f'Scripts/{name}.lua' for name in ('commands/guide', 'ui/guide', 'ui/guide_text')),
               *(f'Scripts/{name}.lua'
                 for name in ('commands/cut', 'commands/fight', 'commands/nightop', 'commands/partner', 'commands/race',
                              'commands/session', 'core/keybind', 'core/link', 'core/settings_file', 'core/unreal',
                              'cut/leviathan', 'main', 'nightop/challenges', 'nightop/probe', 'nightop/recruiter',
                              'nightop/recruiter_text', 'nightop/run', 'nightop/shop', 'nightop/waves',
                              'partner/capture', 'partner/hud', 'partner/puppet', 'race/doro', 'race/drive',
                              'race/drive_model', 'race/model', 'race/run', 'session/booth', 'session/chat',
                              'session/group', 'session/join', 'session/saves', 'session/travel', 'ui/kit', 'ui/menu',
                              'ui/model', 'ui/notice', 'ui/text', 'version'))}
    assert set(files) == shipped - {'INSTALL.md', 'LICENSE', 'CHANGELOG.md', 'SHA256SUMS.txt'}, sorted(files)
    assert not [rel for rel in files
                if any(fnmatch(Path(rel).name, bad) for bad in ('coop-*', '*.sav', 'steam_api*', '*.pak', '*.uasset'))]

    # 12. The release zip: the same inputs give the same bytes, with the commit's time and one mode on every entry,
    # in sorted names, and SHA256SUMS.txt covers every other entry, the docs included.
    when = 1760000000  # An even second: a zip stores times in two-second steps.
    zips = [tmp / 'a/one.zip', tmp / 'b/two.zip']
    for path in zips: install.write_zip(path, files, '# changes\n', when)
    assert zips[0].read_bytes() == zips[1].read_bytes()
    with zipfile.ZipFile(zips[0]) as archive:
        entries = archive.infolist()
        assert [e.filename for e in entries] == sorted(f'StellarCoop/{rel}' for rel in shipped)
        for e in entries:
            assert (e.date_time, e.external_attr, e.compress_type) == (time.gmtime(when)[:6], 0o100644 << 16,
                                                                      zipfile.ZIP_DEFLATED), e
        assert archive.read('StellarCoop/CHANGELOG.md') == b'# changes\n'
        sums = archive.read('StellarCoop/SHA256SUMS.txt').decode()
        assert sums == ''.join(f'{hashlib.sha256(archive.read(e)).hexdigest()}  {e.filename[len("StellarCoop/"):]}\n'
                               for e in entries if e.filename != 'StellarCoop/SHA256SUMS.txt'), sums
        assert '  CHANGELOG.md\n' in sums and '  INSTALL.md\n' in sums and '  LICENSE\n' in sums

# 13. CHANGELOG.md: features and fixes from the commit subjects, newest first; other types and empty sections left out.
head = '# StellarCoop v1\n\nBuilt from the commit of 2025-10-09; generated from the commit history.\n'
assert install.changelog('v1', 1760000000, ['feat: a', 'feat(native)!: b', 'fix: c', 'docs: d', 'test: e']) == (
    f'{head}\n## Features\n- a\n- native: b (breaking)\n\n## Fixes\n- c\n')
assert install.changelog('v1', 1760000000, ['docs: d', 'fix(tools): c']) == f'{head}\n## Fixes\n- tools: c\n'

print('install_test: ok')
