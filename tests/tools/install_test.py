#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/install.py backup, install, uninstall and the release zip on a fake game folder in a temporary directory.
Run: python3 tests/tools/install_test.py"""
import contextlib
import faulthandler
import hashlib
import io
import re
import shutil
import subprocess
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


def link(path, folder, checks):
    """Makes path a symbolic link to folder: True. Where this user may not make one (Windows without Developer Mode:
    WinError 1314), prints the checks that go untested and returns False. Any other error fails the test."""
    try:
        path.symlink_to(folder, target_is_directory=True)
        return True
    except OSError as error:
        if getattr(error, 'winerror', None) != 1314: raise
        print(f'install_test: {checks} not tested: this user may not make symbolic links ({error})')
        return False


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
    dropped = 'Scripts/old\u00e9.lua'  # Part 2 drops it. Out of the f-string: Python 3.11 refuses a backslash there.
    v1 = {'enabled.txt': b'', 'Scripts/main.lua': b'main', dropped: b'old', 'StellarCoop.dll': b'dll 1'}
    code, out = run(install.install_files, target, v1)
    assert code is None and out == f'Installed 4 files into {target}\n', out
    manifest = (target / install.MANIFEST).read_bytes()
    assert manifest.decode().splitlines() == sorted(v1)
    assert files_of(target) == {**v1, install.MANIFEST: manifest} and not backups()

    # 2. A reinstall that drops a file removes it, keeps what the mod wrote in game, and backs up first exactly the
    # files it replaces or removes, the manifest included. The dropped file's name is not ASCII: the manifest is UTF-8
    # on every system.
    (target / 'coop-host.log').write_bytes(b'log')
    (target / 'coop-settings.txt').write_bytes(b'send_rate=20\n')
    v2 = {'enabled.txt': b'', 'Scripts/main.lua': b'main 2', 'StellarCoop.dll': b'dll 2'}
    code, out = run(install.install_files, target, v2)
    first, = backups()
    dest = first / 'StellarCoop'
    assert code is None and re.fullmatch(r'\d{8}T\d{6}Z', first.name), out
    assert out == (f'Backed up 5 files into {dest}\nRemoving {target / dropped}\n'
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
    # anything. It once looped forever, so a timer (exit 1 after a traceback) turns a hang into a failure. Windows has
    # no signal.alarm.
    backups_root, install.BACKUPS = install.BACKUPS, tmp / 'backups-link'
    if link(install.BACKUPS, tmp / 'unmounted', '3b (a backup folder linked to an unmounted disk)'):
        before = tree()
        faulthandler.dump_traceback_later(10, exit=True)
        for call in (lambda: install.install_files(target, v1), lambda: install.uninstall(target, False)):
            try:
                call()
                raise AssertionError('no error')
            except FileExistsError as error:
                assert error.filename == str(install.BACKUPS), error
        faulthandler.cancel_dump_traceback_later()
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
    if linked := link(target, tmp / 'checkout', '10 (a mod folder linked to a checkout)'):
        before = tree()
        assert uninstall() == (left_alone, '') and tree() == before

    # 11. The package content check: the shipped files plus the six docs, nothing the mod writes in game, no save
    # and no game file. A stray file in mod/StellarCoop fails here, so it fails the dry run.
    dll = tmp / 'StellarCoop.dll'
    dll.write_bytes(b'dll')
    files = install.package('v', dll)
    docs = {'INSTALL.md', 'LICENSE', 'NOTICE', 'EXCLUDED-PARTIES.md', 'CHANGELOG.md', 'SHA256SUMS.txt'}
    shipped = {'enabled.txt', 'StellarCoop.dll', *docs,
               'Assets/MotherSphere.png', 'Scripts/online/modes/race/match/tracks/xion_eight.txt',
               *(f'Scripts/{name}.lua' for name in ('ui/kit/commands', 'ui/kit/guide', 'ui/text/guide')),
               *(f'Scripts/{name}.lua'
                 for name in ('vehicles/bike/fetch', 'vehicles/bike/model', 'vehicles/bike/others',
                              'vehicles/bike/paint', 'vehicles/bike/park', 'vehicles/bike/ride',
                              'vehicles/bike/rig', 'vehicles/bike/stand',
                              'online/session/commands', 'online/lobby/commands', 'online/group/commands',
                              'online/saves/commands',
                              'online/partner/commands', 'online/photo/commands', 'online/modes/nightop/commands',
                              'online/modes/race/commands',
                              'fight/enemies/commands', 'story/quests/commands', 'fight/bosses/commands',
                              'eve/commands',
                              'story/scenes/commands', 'cutmenus/commands', 'world/maps/matrix13/commands',
                              'story/together/commands',
                              'world/objects/commands', 'vehicles/bike/commands', 'world/daynight/commands',
                              'world/teamshop/commands', 'world/teamshop/shop',
                              'fight/gunmode/commands',
                              *(f'fight/gunmode/{name}' for name in ('aim', 'ammo', 'config', 'data', 'facts', 'g0',
                                                                     'ik', 'input', 'journal', 'laser', 'mode',
                                                                     'nikke', 'overlay', 'probe', 'release_check',
                                                                     'rifle', 'rows', 'stance', 'ui/slot')),
                              'core/keybind', 'core/link',
                              'core/mask', 'core/pak_gate', 'core/settings_file',
                              'core/unreal', 'core/ue4ss_settings', 'eve/chainspin', 'cutmenus/devmenu',
                              'eve/emote', 'core/enemy', 'eve/flight',
                              'eve/glide', 'fight/bosses/gardener', 'fight/bosses/leviathan',
                              'story/scenes/lines', 'fight/bosses/lion', 'fight/bosses/lion_rows', 'cutmenus/mailbox',
                              'eve/chainspin_rows', 'world/maps/matrix13/level/boss_rows',
                              'story/scenes/scene', 'fight/bosses/tendril', 'eve/wear', 'main',
                              'world/maps/matrix13/culture', 'world/maps/matrix13/words',
                              *(f'world/maps/matrix13/text/{c}'
                                for c in ('ko', 'en-GB', 'de', 'it', 'es', 'es-MX', 'pt', 'pt-BR', 'nl', 'da', 'no',
                                          'sv', 'fi', 'pl', 'ru', 'tr', 'ar', 'th', 'ja', 'zh-Hans', 'zh-Hant')),
                              'world/maps/matrix13/quest/on_time',
                              'world/maps/matrix13/quest/text', 'world/maps/matrix13/quest/zone_talks',
                              *(f'world/maps/matrix13/talks/{talk}' for talk in ('prologue', 'arrival', 'finale',
                                                                                 'zone1', 'zone2', 'zone3', 'zone4')),
                              'world/maps/matrix13/level/boss', 'world/maps/matrix13/level/breakables',
                              'world/maps/matrix13/level/drone', 'world/maps/matrix13/level/fans',
                              'world/maps/matrix13/level/mila', 'world/maps/matrix13/level/move',
                              'world/maps/matrix13/level/rows',
                              'world/maps/matrix13/level/travel',
                              'online/modes/nightop/board', 'online/modes/nightop/challenges',
                              'online/modes/nightop/guard_text',
                              'online/modes/nightop/probe',
                              'online/modes/nightop/recruiter', 'online/modes/nightop/recruiter_text',
                              'online/modes/nightop/roxanne', 'online/modes/nightop/roxanne_text',
                              'online/modes/nightop/run', 'online/modes/nightop/shop',
                              'online/modes/nightop/waves',
                              'online/partner/assets', 'online/partner/capture', 'online/partner/ghosts',
                              'online/partner/hud', 'online/partner/puppet', 'online/partner/sentinel',
                              'vehicles/bike/drive', 'vehicles/bike/drive_model', 'fight/bosses/enemy',
                              'online/partner/bike_part',
                              'online/partner/doro_pick',
                              'online/partner/bench',
                              'online/modes/race/doro',
                              'online/modes/race/drive',
                              'online/modes/race/drive_model', 'online/modes/race/model', 'online/modes/race/run',
                              'online/modes/race/match/model', 'online/modes/race/match/round',
                              'online/modes/race/match/tracks', 'online/modes/race/match/game',
                              'online/modes/race/ui/hud',
                              'online/session/booth', 'online/session/chat',
                              'online/group/group', 'online/lobby/halls_rows', 'world/teamshop/rows',
                              'online/session/join',
                              'online/saves/saves', 'online/lobby/sbo',
                              'online/lobby/arrival', 'online/lobby/sbo_maps', 'online/group/travel',
                              'world/daynight/daynight', 'world/daynight/rule',
                              'story/together/snapshot',
                              'world/maps/matrix13/quest/subtitles', 'online/session/ui/create',
                              'online/session/ui/create_model', 'ui/kit/kit',
                              'online/lobby/ui/lobby',
                              'online/lobby/ui/lobby_model', 'ui/kit/menu', 'ui/kit/model', 'ui/kit/notice',
                              'ui/kit/parts',
                              'ui/kit/pause_tab',
                              'online/group/region_tabs', 'online/session/ui/sessions',
                              'online/session/ui/sessions_model', 'ui/text',
                              'core/line',
                              'core/player',
                              'core/actors',
                              'core/where',
                              'core/row_edit',
                              'core/picks',
                              'core/items',
                              'core/effect',
                              'core/worlds',
                              'core/keep',
                              'ui/kit/hud_parts',
                              'ui/text/culture',
                              *(f'ui/text/{c}' for c in ('en', 'fr', 'ar', 'da', 'de', 'es', 'es-MX', 'fi', 'it',
                                                         'ja', 'ko', 'nl', 'no', 'pl', 'pt', 'pt-BR', 'ru', 'sv',
                                                         'th', 'tr', 'zh-Hans', 'zh-Hant')),
                              *(f'main/{name}' for name in ('boot', 'base', 'loader', 'commands', 'ui', 'input',
                                                             'frame', 'pass', 'keys')),
                              'online/modes/scoreattack/commands', 'online/modes/scoreattack/challenges',
                              'online/modes/scoreattack/model', 'online/modes/scoreattack/waves',
                              'online/modes/scoreattack/round', 'online/modes/scoreattack/run',
                              'online/modes/scoreattack/game', 'online/modes/scoreattack/ui/board',
                              'online/modes/fishing/commands', 'online/modes/fishing/model',
                              'online/modes/fishing/records', 'online/modes/fishing/rows',
                              'online/modes/fishing/round', 'online/modes/fishing/game',
                              'online/modes/fishing/ui/board',
                              'online/modes/photohunt/commands', 'online/modes/photohunt/model',
                              'online/modes/photohunt/records', 'online/modes/photohunt/targets',
                              'online/modes/photohunt/round', 'online/modes/photohunt/game',
                              'online/modes/photohunt/ui/board',
                              *(f'{module}/wiring' for module in ('online/partner', 'online/modes/nightop',
                                                                  'fight/bosses', 'online/group',
                                                                   'online/modes/race', 'eve', 'story/scenes',
                                                                   'world/maps/matrix13',
                                                                   'online/session', 'online/photo', 'fight/enemies',
                                                                   'story/quests', 'world/objects',
                                                                   'story/together', 'online/lobby', 'vehicles/bike',
                                                                   'world/daynight', 'cutmenus',
                                                                   'online/saves', 'world/teamshop',
                                                                   'fight/gunmode', 'online/modes/scoreattack',
                                                                   'online/modes/fishing', 'online/modes/photohunt')),
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
    if linked: target.unlink()  # The link of 10: no mod folder now.
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

    # 20. --ue4ss writes SBO's UE4SS package (tools/ue4ss.py) into SB/Binaries/Win64 over a 1.3 install. It first
    # backs up each file it replaces or removes. The signature scripts the package lacks (FText_Constructor.lua,
    # another build's) and the 1.3 package's Changelog.md go. The player's mods.txt, other mods, StellarCoop, the
    # .example files, the log, the usmap and the game stay.
    win64 = tmp / 'game3/SB/Binaries/Win64'
    old13 = {'dwmapi.dll': b'proxy 1.3', 'ue4ss/UE4SS.dll': b'ue4ss 3.0.1', 'ue4ss/UE4SS-settings.ini': b'settings 1.3',
             'ue4ss/MemberVariableLayout.ini': b'layout 1.3', 'ue4ss/VTableLayout.ini': b'vtables 1.3',
             'ue4ss/Changelog.md': b'rc1', 'ue4ss/UE4SS_Signatures/FText_Constructor.lua': b'ftext',
             'ue4ss/UE4SS_Signatures/GNatives.lua': b'gnatives 1.3',
             'ue4ss/Mods/Keybinds/Scripts/main.lua': b'keys 1.3'}
    kept = {'ue4ss/Mods/mods.txt': b'ConsoleEnablerMod : 1\r\nKeybinds : 1\r\n',
            'ue4ss/Mods/ConsoleEnablerMod/Scripts/main.lua': b'console 1.3', 'ue4ss/Mods/StellarCoop/enabled.txt': b'',
            'ue4ss/UE4SS_Signatures/GUObjectArray.lua.example': b'example', 'ue4ss/UE4SS.log': b'log',
            'ue4ss/SB-4.26.2-0+++UE4+Release-4.26-08a0733.usmap': b'usmap', 'SB-Win64-Shipping.exe': b'game'}
    put(win64, {**old13, **kept})
    ue4ss_files = {'dwmapi.dll': b'proxy 4', 'ue4ss/UE4SS.dll': b'ue4ss 4', 'ue4ss/LICENSE': b'MIT',
                   'ue4ss/UE4SS-settings.ini': b'sbo settings', 'ue4ss/MemberVariableLayout.ini': b'sbo layout',
                   'ue4ss/VTableLayout.ini': b'vtables', 'ue4ss/UE4SS_Signatures/GNatives.lua': b'gnatives',
                   'ue4ss/UE4SS_Signatures/GUObjectArray.lua': b'guobjectarray',
                   'ue4ss/Mods/mods.txt': b'Keybinds : 1\r\n', 'ue4ss/Mods/Keybinds/Scripts/main.lua': b'keys 4'}
    gone = [win64 / 'ue4ss/Changelog.md', win64 / 'ue4ss/UE4SS_Signatures/FText_Constructor.lua']
    before = tree()
    assert run(install.install_ue4ss, win64, ue4ss_files, True) == (
        None, 'Dry run: would back up 9 UE4SS files first\n' + ''.join(f'Dry run: would remove {p}\n' for p in gone)
        + f'Dry run: would install 9 UE4SS files into {win64}\n') and tree() == before
    install.running_game = lambda: True
    assert run(install.install_ue4ss, win64, ue4ss_files, False) == (CLOSE, '') and tree() == before
    install.running_game = lambda: False
    old = set(backups())
    code, out = run(install.install_ue4ss, win64, ue4ss_files, False)
    new, = set(backups()) - old
    assert code is None and out == (f'Backed up 9 files into {new / "Win64"}\n'
                                    + ''.join(f'Removing {p}\n' for p in gone)
                                    + f'Installed 9 UE4SS files into {win64}\n'), out
    assert files_of(new / 'Win64') == old13
    assert files_of(win64) == {**kept, **{r: d for r, d in ue4ss_files.items() if r != 'ue4ss/Mods/mods.txt'}}
    # A game folder without UE4SS gets the whole package with its mods.txt. Nothing is backed up.
    win64b = tmp / 'game4/SB/Binaries/Win64'
    win64b.mkdir(parents=True)
    old = set(backups())
    assert run(install.install_ue4ss, win64b, ue4ss_files, False) == (
        None, f'Installed 10 UE4SS files into {win64b}\n')
    assert files_of(win64b) == ue4ss_files and set(backups()) == old
    # python3 -I leaves the script's folder out of sys.path, as the gate runs install.py. install.py adds that folder
    # itself, so it still finds tools/ue4ss.py.
    done = subprocess.run([sys.executable, '-I', install.__file__, '--help'], capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0 and '--ue4ss' in done.stdout, (done.returncode, done.stderr)

    # 21. main with --ue4ss: never with --zip or --uninstall. A game folder without the executable, an executable with
    # no build set in ue4ss/builds/ and a cached release zip of other bytes each stop it before the tests. Then its dry
    # run and its install each say the mod's lines, then the UE4SS lines. A Win64 folder without UE4SS is enough.
    def header(stamp, size):
        """The first 0x100 bytes of a 64-bit PE file with this TimeDateStamp and SizeOfImage."""
        head = bytearray(0x100)
        head[:2], head[0x3c:0x40], head[0x80:0x84] = b'MZ', (0x80).to_bytes(4, 'little'), b'PE\0\0'
        head[0x88:0x8c], head[0x98:0x9a] = stamp.to_bytes(4, 'little'), (0x20b).to_bytes(2, 'little')
        head[0xd0:0xd4] = size.to_bytes(4, 'little')
        return bytes(head)

    def with_ue4ss(*extra):
        return run(install.main, ['--ue4ss', *extra, '--game', str(tmp / 'game5')])

    win64c = tmp / 'game5/SB/Binaries/Win64'
    target5, exe = win64c / 'ue4ss/Mods/StellarCoop', win64c / 'SB-Win64-Shipping.exe'
    for other in ('--zip', '--uninstall'):
        code, out = with_ue4ss(other)
        assert code == 2 and 'argument --ue4ss: not allowed with --zip or --uninstall' in out, (code, out)
    saved = install.subprocess, install.sanitizers, install.version, install.package, install.ue4ss.CACHE
    install.subprocess = types.SimpleNamespace(run=tests_ran)
    try:
        code, out = with_ue4ss()
        assert code.startswith(f'Cannot read {exe}: ') and out == '', (code, out)
        win64c.mkdir(parents=True)
        exe.write_bytes(header(0x6ad8eff1, 0x15fa3001))
        builds = ', '.join(sorted(p.name for p in install.ue4ss.BUILDS.iterdir()))
        assert with_ue4ss() == (f'SBO has no UE4SS files for this Stellar Blade build (6ad8eff1-15fa3001), only for '
                                f'{builds}. SBO waits for an update. Nothing was written.', '')
        exe.write_bytes(header(0x6ad8eff1, 0x15fa3000))  # Build 26123051's, as check_build() pins it.
        install.ue4ss.CACHE = tmp / 'cache/UE4SS_v4.0.0.zip'
        put(install.ue4ss.CACHE.parent, {install.ue4ss.CACHE.name: b'not the release'})
        assert with_ue4ss() == (f'{install.ue4ss.CACHE} is not the UE4SS v4.0.0 release zip (SHA-256 '
                                f'{hashlib.sha256(b"not the release").hexdigest()}, expected {install.ue4ss.SHA256}): '
                                'refused', '')
        assert sorted(p.relative_to(tmp / 'game5').as_posix() for p in (tmp / 'game5').rglob('*')) == [
            'SB', 'SB/Binaries', 'SB/Binaries/Win64', 'SB/Binaries/Win64/SB-Win64-Shipping.exe']
        install.subprocess = types.SimpleNamespace(run=lambda *args, **kwargs: None, DEVNULL=None)
        install.sanitizers, install.version = (lambda: []), (lambda: 'v')
        install.package = lambda ver, dll: {'enabled.txt': b''}
        packaged = []
        real_package, install.ue4ss.package = install.ue4ss.package, lambda path: packaged.append(path) or ue4ss_files
        try:
            assert with_ue4ss('--dry-run') == (None, f'Version: v\nDry run: would install 1 files into {target5}\n'
                                                     f'Dry run: would install 10 UE4SS files into {win64c}\n')
            assert sorted(p.name for p in win64c.iterdir()) == ['SB-Win64-Shipping.exe']
            assert with_ue4ss() == (None, f'Version: v\nInstalled 1 files into {target5}\n'
                                          f'Installed 10 UE4SS files into {win64c}\n')
        finally: install.ue4ss.package = real_package
        assert packaged == [exe, exe], packaged
    finally:
        install.subprocess, install.sanitizers, install.version, install.package, install.ue4ss.CACHE = saved
    assert files_of(win64c) == {**ue4ss_files, 'SB-Win64-Shipping.exe': header(0x6ad8eff1, 0x15fa3000),
                                'ue4ss/Mods/StellarCoop/enabled.txt': b'',
                                f'ue4ss/Mods/StellarCoop/{install.MANIFEST}': b'enabled.txt\n'}

# 13. CHANGELOG.md: features and fixes from the commit subjects, newest first; other types and empty sections left out.
# The subjects are those after the last GPL-3.0 commit: none of 0.9.0's history.
head = '# StellarCoop v1\n\nBuilt from the commit of 2025-10-09; generated from the commits after 0.9.0.\n'
assert install.changelog('v1', 1760000000, ['feat: a', 'feat(native)!: b', 'fix: c', 'docs: d', 'test: e']) == (
    f'{head}\n## Features\n- a\n- native: b (breaking)\n\n## Fixes\n- c\n')
assert install.changelog('v1', 1760000000, ['docs: d', 'fix(tools): c']) == f'{head}\n## Fixes\n- tools: c\n'
install.git('merge-base', '--is-ancestor', install.LAST_GPL, 'HEAD')  # Fails when the range would not start there.
assert install.subjects() and 'chore(main): release 0.9.0' not in install.subjects()

print('install_test: ok')
