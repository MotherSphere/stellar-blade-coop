#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
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

    # 11. The package content check: the shipped files plus the six docs, nothing the mod writes in game, no save
    # and no game file. A stray file in mod/StellarCoop fails here, so it fails the dry run.
    dll = tmp / 'StellarCoop.dll'
    dll.write_bytes(b'dll')
    files = install.package('v', dll)
    docs = {'INSTALL.md', 'LICENSE', 'NOTICE', 'EXCLUDED-PARTIES.md', 'CHANGELOG.md', 'SHA256SUMS.txt'}
    shipped = {'enabled.txt', 'StellarCoop.dll', *docs,
               'Assets/MotherSphere.png',
               *(f'Scripts/{name}.lua' for name in ('ui/kit/commands', 'ui/kit/guide', 'ui/text/guide')),
               *(f'Scripts/{name}.lua'
                 for name in ('bike/fetch', 'bike/model', 'bike/others', 'bike/park', 'bike/ride', 'bike/stand',
                              'session/commands', 'lobby/commands', 'group/commands', 'save/commands',
                              'partner/commands', 'photo/commands', 'nightop/commands', 'race/commands',
                              'fight/commands', 'quest/commands', 'cut/enemies/commands', 'cut/eve/commands',
                              'cut/scenes/commands', 'cut/menus/commands', 'matrix13/commands', 'story/commands',
                              'world/commands', 'bike/commands', 'sky/commands', 'core/keybind', 'core/link',
                              'core/mask', 'core/pak_gate', 'core/settings_file',
                              'core/unreal', 'core/ue4ss_settings', 'cut/eve/chainspin', 'cut/menus/devmenu',
                              'cut/eve/emote', 'core/enemy', 'cut/eve/flight',
                              'cut/eve/glide', 'cut/enemies/gardener', 'cut/enemies/leviathan',
                              'cut/scenes/lines', 'cut/enemies/lion', 'core/lion_rows', 'cut/menus/mailbox',
                              'cut/scenes/scene', 'cut/enemies/tendril', 'cut/eve/wear', 'main',
                              'matrix13/culture', 'matrix13/quest/on_time', 'matrix13/quest/text', 'matrix13/quest/zone_talks',
                              *(f'matrix13/talks/{talk}' for talk in ('prologue', 'arrival', 'finale', 'zone1',
                                                                       'zone2', 'zone3', 'zone4')),
                              'matrix13/world/boss', 'matrix13/world/breakables',
                              'matrix13/world/drone', 'matrix13/world/fans', 'matrix13/world/mila', 'matrix13/world/move', 'matrix13/world/rows',
                              'matrix13/world/travel',
                              'nightop/board', 'nightop/challenges', 'nightop/guard_text',
                              'nightop/probe',
                              'nightop/recruiter', 'nightop/recruiter_text', 'nightop/roxanne', 'nightop/roxanne_text',
                              'nightop/run', 'nightop/shop',
                              'nightop/waves',
                              'partner/capture', 'partner/ghosts', 'partner/hud', 'partner/puppet', 'partner/sentinel',
                              'bike/drive', 'bike/drive_model', 'cut/enemies/enemy', 'partner/bike_part',
                              'partner/doro_pick',
                              'race/doro',
                              'race/drive',
                              'race/drive_model', 'race/model', 'race/run', 'session/booth', 'session/chat',
                              'group/group', 'lobby/halls_rows', 'session/join', 'save/saves', 'lobby/sbo',
                              'lobby/arrival', 'lobby/sbo_maps', 'group/travel', 'sky/daynight', 'sky/rule',
                              'story/snapshot',
                              'matrix13/quest/subtitles', 'session/ui/create', 'session/ui/create_model', 'ui/kit/kit',
                              'lobby/ui/lobby',
                              'lobby/ui/lobby_model', 'ui/kit/menu', 'ui/kit/model', 'ui/kit/notice', 'ui/kit/parts',
                              'ui/kit/pause_tab',
                              'group/region_tabs', 'session/ui/sessions', 'session/ui/sessions_model', 'ui/text',
                              'core/line',
                              'core/player',
                              'core/actors',
                              'core/where',
                              'core/row_edit',
                              'core/picks',
                              'core/items',
                              'core/effect',
                              'core/worlds',
                              'ui/kit/hud_parts',
                              'ui/text/culture',
                              *(f'main/{name}' for name in ('boot', 'base', 'loader', 'commands', 'ui', 'input',
                                                             'frame', 'pass', 'keys')),
                              *(f'{module}/wiring' for module in ('partner', 'nightop', 'cut/enemies', 'group',
                                                                   'race', 'cut/eve', 'cut/scenes', 'matrix13',
                                                                   'session', 'photo', 'fight', 'quest', 'world',
                                                                   'story', 'lobby', 'bike', 'sky', 'cut/menus',
                                                                   'save')),
                              'version'))}
    assert set(files) == shipped - docs, sorted(files)
    assert not [rel for rel in files
                if any(fnmatch(Path(rel).name, bad) for bad in ('coop-*', '*.sav', 'steam_api*', '*.pak', '*.uasset'))]

    # 12. The release zip: the same inputs give the same bytes, with the commit's time and one mode on every entry,
    # in sorted names, and SHA256SUMS.txt covers every other entry, the docs included. The art is installed, not zipped.
    when = 1760000000  # An even second: a zip stores times in two-second steps.
    zips = [tmp / 'a/one.zip', tmp / 'b/two.zip']
    for path in zips: install.write_zip(path, files, '# changes\n', when)
    assert zips[0].read_bytes() == zips[1].read_bytes()
    with zipfile.ZipFile(zips[0]) as archive:
        entries = archive.infolist()
        assert [e.filename for e in entries] == sorted(f'StellarCoop/{rel}' for rel in shipped - {install.ART})
        for e in entries:
            assert (e.date_time, e.external_attr, e.compress_type) == (time.gmtime(when)[:6], 0o100644 << 16,
                                                                      zipfile.ZIP_DEFLATED), e
        assert archive.read('StellarCoop/CHANGELOG.md') == b'# changes\n'
        sums = archive.read('StellarCoop/SHA256SUMS.txt').decode()
        assert sums == ''.join(f'{hashlib.sha256(archive.read(e)).hexdigest()}  {e.filename[len("StellarCoop/"):]}\n'
                               for e in entries if e.filename != 'StellarCoop/SHA256SUMS.txt'), sums
        assert all(f'  {name}\n' in sums for name in docs - {'SHA256SUMS.txt'}), sums
        for name in install.DOCS:  # The license files go into the zip as they are in the repository.
            assert archive.read(f'StellarCoop/{name}') == (install.ROOT / name).read_bytes(), name
        assert b'SBO License' in archive.read('StellarCoop/LICENSE')

    def put(root, files):
        for rel, data in files.items():
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_bytes(data)

    # 14. --pak copies the three hall lobby pak files of its folder into ~mods, made when missing, and nothing else of
    # that folder. A fresh copy backs up nothing.
    paks = install.GAME / 'SB/Content/Paks'
    lobby, src = paks / '~mods', tmp / 'pak'
    pak1, pak2 = ({name: f'{name} {n}'.encode() for name in install.PAK} for n in (1, 2))
    put(paks, {'LogicMods/x.pak': b'logic'})
    put(src, {**pak1, 'SHA256SUMS': b'sums'})
    count = len(backups())
    code, out = run(install.install_pak, install.pak_sources(src), lobby, False)
    assert code is None and out == f'Installed 3 pak files into {lobby}\n', out
    assert files_of(paks) == {'LogicMods/x.pak': b'logic', **{f'~mods/{n}': d for n, d in pak1.items()}}
    assert len(backups()) == count

    # 15. A reinstall backs up the three files it replaces and only them: the Matrix XIII pak, another mod's folder in
    # ~mods and LogicMods are never read, backed up or changed.
    others = {**{f'~mods/zMXIII_P.{ext}': f'mxiii {ext}'.encode() for ext in ('pak', 'ucas', 'utoc')},
              '~mods/CustomNanosuitSystem/x.pak': b'cns', 'LogicMods/x.pak': b'logic'}
    put(paks, others)
    put(src, pak2)
    old = set(backups())
    code, out = run(install.install_pak, install.pak_sources(src), lobby, False)
    new, = set(backups()) - old
    assert code is None and out == f'Backed up 3 files into {new / "Paks"}\nInstalled 3 pak files into {lobby}\n', out
    assert files_of(new / 'Paks') == pak1
    assert files_of(paks) == {**others, **{f'~mods/{n}': d for n, d in pak2.items()}}

    # 16. A copy that does not hash like its source stops the install and names the file. A folder without one of the
    # three files is refused before anything is copied.
    shutil_, install.shutil = install.shutil, types.SimpleNamespace(
        copy2=shutil.copy2, copyfile=lambda a, b: Path(b).write_bytes(b'torn'))
    try:
        code, out = run(install.install_pak, install.pak_sources(src), lobby, False)
    finally: install.shutil = shutil_
    assert code == f'{lobby / "zSBO_Lobby.pak"} does not hash like {src / "zSBO_Lobby.pak"}: run --pak again', code
    assert run(install.install_pak, install.pak_sources(src), lobby, False)[0] is None
    assert files_of(paks) == {**others, **{f'~mods/{n}': d for n, d in pak2.items()}}
    (src / 'zSBO_Lobby.ucas').rename(tmp / 'aside.ucas')
    assert run(install.pak_sources, src) == (f'No zSBO_Lobby.ucas in {src}', '')
    (tmp / 'aside.ucas').rename(src / 'zSBO_Lobby.ucas')

    # 17. A pak dry run says what it would do and changes nothing. While the game runs, a pak install and an uninstall
    # with the pak in ~mods change nothing either.
    before = tree()
    assert run(install.install_pak, install.pak_sources(src), lobby, True) == (
        None, f'Dry run: would back up 3 pak files first\nDry run: would install 3 pak files into {lobby}\n')
    assert tree() == before
    install.running_game = lambda: True
    assert run(install.install_pak, install.pak_sources(src), lobby, False) == (CLOSE, '')
    assert uninstall() == (CLOSE, '') and tree() == before
    install.running_game = lambda: False

    # 18. An uninstall backs up and removes the three pak files and nothing else in ~mods or LogicMods, first without
    # the mod folder, then with an installed one; its dry run says so. With no pak left it says nothing about one.
    target.unlink()  # The link of 10: no mod folder now.
    nothing = f'Nothing to uninstall: no StellarCoop folder at {target}\n'
    before = tree()
    assert uninstall('--dry-run') == (None, f'Dry run: would back up 3 pak files into {install.BACKUPS} and remove '
                                            f'them from {lobby}\n{nothing}') and tree() == before
    old = set(backups())
    code, out = uninstall()
    new, = set(backups()) - old
    assert code is None and out == (f'Backed up 3 files into {new / "Paks"}\n'
                                    + ''.join(f'Removed {lobby / name}\n' for name in install.PAK) + nothing), out
    assert files_of(new / 'Paks') == pak2 and files_of(paks) == others
    before = tree()
    assert uninstall() == (None, nothing) and tree() == before
    # A tester's uninstall: the pak and an installed mod folder. The pak goes first, each into its own backup folder
    # (one frozen second, so the mod's gets -1).
    (mods / 'mods.txt').write_bytes(b'BPModLoaderMod : 1\n')  # 9's StellarCoop line would add its report.
    assert run(install.install_files, target, v2)[0] is None
    assert run(install.install_pak, install.pak_sources(src), lobby, False)[0] is None
    clock = install.time
    install.time = types.SimpleNamespace(strftime=time.strftime, gmtime=lambda: time.gmtime(0))
    try:
        code, out = uninstall()
    finally: install.time = clock
    pak_dest, mod_dest = install.BACKUPS / '19700101T000000Z/Paks', install.BACKUPS / '19700101T000000Z-1/StellarCoop'
    assert code is None and out == (f'Backed up 3 files into {pak_dest}\n'
                                    + ''.join(f'Removed {lobby / name}\n' for name in install.PAK)
                                    + f'Backed up 4 files into {mod_dest}\nRemoved {target}\n{SAVES_LINE}'), out
    assert files_of(pak_dest) == pak2 and files_of(paks) == others and not target.exists()
    assert files_of(mod_dest) == {**v2, install.MANIFEST: b''.join(f'{r}\n'.encode() for r in sorted(v2))}

    # 19. main with --pak, on a new game folder: no Paks folder, or a folder without the three files, stops it before
    # the tests (a run of them would run this test again). Then its dry run and its install each say the mod's line,
    # then the pak's, and the install copies the pak.
    game2 = tmp / 'game2'
    target2, lobby2 = game2 / 'SB/Binaries/Win64/ue4ss/Mods/StellarCoop', game2 / 'SB/Content/Paks/~mods'
    target2.parent.mkdir(parents=True)
    (tmp / 'empty').mkdir()
    saved = install.subprocess, install.sanitizers, install.version, install.package

    def pak(folder, *extra):
        return run(install.main, ['--pak', str(folder), *extra, '--game', str(game2)])

    def tests_ran(*args, **kwargs):
        raise AssertionError('main ran the tests')

    install.subprocess = types.SimpleNamespace(run=tests_ran)
    try:
        assert pak(src) == (f'No Paks folder at {lobby2.parent}', '')
        lobby2.parent.mkdir(parents=True)
        assert pak(tmp / 'empty') == (f'No {", ".join(install.PAK)} in {tmp / "empty"}', '')
        install.subprocess = types.SimpleNamespace(run=lambda *args, **kwargs: None, DEVNULL=None)
        install.sanitizers, install.version = (lambda: []), (lambda: 'v')
        install.package = lambda ver, dll: {'enabled.txt': b''}
        assert pak(src, '--dry-run') == (None, f'Version: v\nDry run: would install 1 files into {target2}\n'
                                               f'Dry run: would install 3 pak files into {lobby2}\n')
        assert not target2.exists() and not lobby2.exists()
        assert pak(src) == (None, f'Version: v\nInstalled 1 files into {target2}\n'
                                  f'Installed 3 pak files into {lobby2}\n')
    finally: install.subprocess, install.sanitizers, install.version, install.package = saved
    assert files_of(lobby2) == pak2

# 13. CHANGELOG.md: features and fixes from the commit subjects, newest first; other types and empty sections left out.
# The subjects are those after the last GPL-3.0 commit: none of 0.9.0's history.
head = '# StellarCoop v1\n\nBuilt from the commit of 2025-10-09; generated from the commits after 0.9.0.\n'
assert install.changelog('v1', 1760000000, ['feat: a', 'feat(native)!: b', 'fix: c', 'docs: d', 'test: e']) == (
    f'{head}\n## Features\n- a\n- native: b (breaking)\n\n## Fixes\n- c\n')
assert install.changelog('v1', 1760000000, ['docs: d', 'fix(tools): c']) == f'{head}\n## Fixes\n- tools: c\n'
install.git('merge-base', '--is-ancestor', install.LAST_GPL, 'HEAD')  # Fails when the range would not start there.
assert install.subjects() and 'chore(main): release 0.9.0' not in install.subjects()

print('install_test: ok')
