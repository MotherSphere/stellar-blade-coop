#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Checks and builds StellarCoop, then copies it into Stellar Blade's UE4SS Mods folder (never while the game runs).
What an install replaces or removes is backed up first; --uninstall backs up the whole folder, then removes it.
--zip writes a release zip that the same commit always gives byte for byte, with a CHANGELOG.md from the commits made
after the last GPL-3.0 commit. --pak also copies the hall lobby pak, kept on this PC and never in the zip, into
SB/Content/Paks/~mods; --uninstall backs up and removes its three files there, and nothing else in ~mods. --ue4ss
also installs SBO's UE4SS package (tools/ue4ss.py) into SB/Binaries/Win64: the official UE4SS v4.0.0 with SBO's build
of UE4SS.dll (tools/ue4ss_build.py), SBO's settings and the files of the game's build. A UE4SS.dll that is not the
pinned build stops it before the tests. It backs up what it replaces or removes."""
import argparse
import concurrent.futures
import hashlib
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import zipfile
from fnmatch import fnmatch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # python3 -I leaves the script's folder out.
import ue4ss  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
GAME = Path('/mnt/Jeux/SteamLibrary/steamapps/common/StellarBlade')
TOOLCHAIN = os.environ.get('STELLAR_WINDOWS_TOOLCHAIN', str(Path.home() / '.local/share/xwin/clang-cl-msvc.cmake'))
MANIFEST = 'install-manifest.txt'
RUNTIME = ('coop-*.log', 'coop-*.txt', '*.old.log')  # Written by the mod in game: never removed.
THUMBS = 'closet-thumbs'  # closet/thumbs.lua's pictures of creators' outfits, made in game: never shipped.
OBSOLETE = {'steam-probe.txt'}  # Left by an old probe, before the manifest existed.
BACKUPS = Path.home() / 'StellarCoop-install-backups'  # Outside the game folder: UE4SS would load a copy under Mods.
CLOSE_GAME = 'Close Stellar Blade first: its mods must not change under it.'
# The last commit released under GPL-3.0 (NOTICE): the zip's changelog lists only the commits after it.
LAST_GPL = '051ab5090a2ea6832279345524e9cdaa816ee736'
ART = 'Assets/MotherSphere.png'  # timediffer24's art, not under the SBO License (NOTICE): installed, never zipped.
PAK = ('zSBO_Lobby.pak', 'zSBO_Lobby.ucas', 'zSBO_Lobby.utoc')  # The only files --pak and --uninstall touch in ~mods.
UE4SS_OLD = ('ue4ss/Changelog.md',)  # The 1.3 package's UE4SS 3.0.1 changelog: --ue4ss moves it into the backup.
# How many tests run side by side: STELLAR_JOBS, else half the CPUs this process may use (a native test built with the
# sanitizers takes a GB of RAM). STELLAR_JOBS=1 runs them one at a time, in the old order.
JOBS = int(os.environ.get('STELLAR_JOBS') or 0) or max(1, len(getattr(os, 'sched_getaffinity', lambda _: range(
    os.cpu_count() or 1))(0)) // 2)


def running_game():
    for path in Path('/proc').glob('[0-9]*/comm'):
        try:
            if path.read_text().strip().startswith('SB-Win64'): return True
        except OSError: pass
    return False


def git(*args):
    return subprocess.run(['git', *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout


def version():
    try:
        return git('describe', '--tags', '--always', '--dirty').strip() or 'dev'
    except (OSError, subprocess.CalledProcessError):
        return 'dev'


class Failed(Exception):
    """A test step that ended with another exit code than 0: its command, the code and what it wrote."""


def step(argv):
    """One test step run from the repository's root. Returns what it wrote, raises Failed with it."""
    done = subprocess.run([str(a) for a in argv], cwd=ROOT, capture_output=True)
    if done is None: return b''  # tests/tools/install_test.py's stand-in.
    if done.returncode: raise Failed(' '.join(str(a) for a in argv), done.returncode, done.stdout + done.stderr)
    return done.stdout + done.stderr


def side_by_side(tasks, jobs=None):
    """Runs the tasks JOBS at a time and writes each one's output in the tasks' own order, so the log reads as a
    run one at a time. The first failure writes its output and stops the run; tasks not started yet never start."""
    stopped = threading.Event()

    def unless_stopped(task):
        if stopped.is_set(): return b''
        try:
            return task()
        except BaseException:
            stopped.set()
            raise

    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs or JOBS) as pool:
        futures = [pool.submit(unless_stopped, task) for task in tasks]
        for future in futures:
            try:
                out = future.result()
            except Failed as failed:
                command, code, out = failed.args
                print(out.decode(errors='replace'), end='', flush=True)
                sys.exit(f'Failed (exit code {code}): {command}')
            print(out.decode(errors='replace'), end='', flush=True)


def built_key(test, flags, compiler):
    """What a built native test depends on, as one hash: the compiler, its flags and the bytes of the test and of
    every file it includes (c++ -MM). None when that list cannot be had: the test is then built again."""
    listed = subprocess.run(['c++', *flags, '-MM', str(test)], cwd=ROOT, capture_output=True)
    if listed is None or listed.returncode: return None
    files = listed.stdout.decode().replace('\\\n', ' ').split(':', 1)[-1].split()
    key = hashlib.sha256(repr((compiler, flags)).encode())
    for name in sorted(files):
        key.update(name.encode() + b'\0' + (ROOT / name).read_bytes())
    return key.hexdigest()


def native_test(test, checks, compiler):
    """One native test: built again only when built_key changed, then run. Its output."""
    exe = ROOT / 'build/host' / '_'.join(test.relative_to(ROOT / 'tests/native').with_suffix('').parts)
    flags = ['-std=c++17', '-Wall', '-Wextra', '-Werror', *checks, '-I', str(ROOT / 'native/src')]
    key, kept, out = built_key(test, flags, compiler), exe.with_name(exe.name + '.key'), b''
    if not (key and exe.is_file() and kept.is_file() and kept.read_text() == key):
        out = step(['c++', *flags, test, '-o', exe])
        if key: kept.write_text(key)
    return out + step([exe])


def sanitizers():
    """ASan and UBSan flags when this compiler can build and run them here, else none."""
    flags = ['-g', '-fsanitize=address,undefined', '-fno-sanitize-recover=all']
    exe = ROOT / 'build/host/sanitizer-probe'
    exe.parent.mkdir(parents=True, exist_ok=True)
    built = subprocess.run(['c++', *flags, '-x', 'c++', '-', '-o', exe], input=b'int main() {}\n', capture_output=True)
    if built.returncode == 0 and subprocess.run([exe], capture_output=True).returncode == 0: return flags
    print('Sanitizers: off (this c++ cannot build or run them)', flush=True)
    return []


def package(ver, dll):
    """Every file the mod folder gets, as {relative path: content}. Nothing under THUMBS."""
    mod = ROOT / 'mod/StellarCoop'
    files = {p.relative_to(mod).as_posix(): p.read_bytes() for p in sorted(mod.rglob('*'))
             if p.is_file() and p.relative_to(mod).parts[0] != THUMBS}
    files['Scripts/version.lua'] = f"return '{ver}'\n".encode()
    files['StellarCoop.dll'] = dll.read_bytes()
    return files


def stale(target, files):
    """Files of the previous install that this one no longer ships, plus known obsolete ones. Logs always stay."""
    manifest = target / MANIFEST
    old = set(manifest.read_text(encoding='utf-8').splitlines()) if manifest.is_file() else set()
    for rel in sorted((old | OBSOLETE) - set(files)):
        path = target / rel
        if (path.is_file() and not any(fnmatch(path.name, keep) for keep in RUNTIME)
                and path.resolve().is_relative_to(target.resolve())):
            yield path


def replaced(target, files):
    """The existing files, relative to target, that an install of these files overwrites or removes."""
    gone = {path.relative_to(target).as_posix() for path in stale(target, files)}
    return sorted(gone | {rel for rel in [*files, MANIFEST] if (target / rel).is_file()})


def backup(target, rels, name='StellarCoop'):
    """Copies these files of target into a new BACKUPS/<UTC time>[-n]/<name> and returns that folder."""
    stamp, n = time.strftime('%Y%m%dT%H%M%SZ', time.gmtime()), 0
    # Outside the loop: a BACKUPS that is a file or a link to an unmounted disk fails here, never retried forever.
    BACKUPS.mkdir(parents=True, exist_ok=True)
    while True:
        dest = BACKUPS / (f'{stamp}-{n}' if n else stamp)
        try:
            dest.mkdir()
            break
        except FileExistsError:  # A second backup within one second: never mixed into the first.
            n += 1
    dest /= name
    for rel in rels:
        (dest / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target / rel, dest / rel)
    print(f'Backed up {len(rels)} files into {dest}')
    return dest


def install_files(target, files):
    """Backs up what this install replaces or removes, removes stale files, then writes the files and the manifest."""
    if running_game(): sys.exit(CLOSE_GAME)
    if rels := replaced(target, files): backup(target, rels)
    for path in stale(target, files):
        print(f'Removing {path}')
        path.unlink()
    for rel, data in files.items():
        (target / rel).parent.mkdir(parents=True, exist_ok=True)
        (target / rel).write_bytes(data)
    # UTF-8 with LF ends on every system: Windows would write its code page and CRLF.
    (target / MANIFEST).write_text(''.join(f'{rel}\n' for rel in sorted(files)), encoding='utf-8', newline='\n')
    print(f'Installed {len(files)} files into {target}')


def uninstall(target, dry_run):
    """Backs up the whole folder (logs and coop-settings.txt included), then removes it. Saves, the slot marker and
    mods.txt are never touched: only a mods.txt line naming the mod is reported."""
    if not target.is_dir(): return print(f'Nothing to uninstall: no StellarCoop folder at {target}')
    if target.is_symlink() or not (target / MANIFEST).is_file():  # A link may be a checkout: never rmtree it.
        sys.exit(f'{target} was not installed by this tool (no {MANIFEST}, or a link): left alone')
    rels = sorted(p.relative_to(target).as_posix() for p in target.rglob('*') if p.is_file())
    if dry_run: return print(f'Dry run: would back up {len(rels)} files into {BACKUPS} and remove {target}')
    if running_game(): sys.exit(CLOSE_GAME)
    backup(target, rels)
    shutil.rmtree(target)
    print(f'Removed {target}')
    listed = target.parent / 'mods.txt'
    if listed.is_file() and any(line.strip().startswith('StellarCoop')
                                for line in listed.read_text(encoding='utf-8-sig', errors='replace').splitlines()):
        print(f'mods.txt still names StellarCoop: remove that line by hand ({listed})')
    print('Saves, the co-op copies and StellarCoopSlot.txt are never touched (INSTALL.md: Co-op saves).')


def subjects():
    """The subjects of the commits after LAST_GPL, newest first: what the zip's changelog lists."""
    return git('log', '--no-merges', '--format=%s', f'{LAST_GPL}..HEAD').splitlines()


def pak_sources(folder):
    """The three hall lobby pak files of folder; a folder without one of them is refused."""
    if missing := [name for name in PAK if not (folder / name).is_file()]:
        sys.exit(f'No {", ".join(missing)} in {folder}')
    return [folder / name for name in PAK]


def sha256(path):
    with path.open('rb') as data: return hashlib.file_digest(data, 'sha256').hexdigest()


def install_pak(sources, paks, dry_run):
    """Backs up the pak files these sources replace in paks (~mods), then copies each one and checks that the copy
    hashes like its source."""
    old = [path.name for path in sources if (paks / path.name).is_file()]
    if dry_run:
        if old: print(f'Dry run: would back up {len(old)} pak files first')
        return print(f'Dry run: would install {len(sources)} pak files into {paks}')
    if running_game(): sys.exit(CLOSE_GAME)
    if old: backup(paks, old, 'Paks')
    paks.mkdir(exist_ok=True)
    for path in sources:
        shutil.copyfile(path, paks / path.name)
        if sha256(paks / path.name) != sha256(path):
            sys.exit(f'{paks / path.name} does not hash like {path}: run --pak again')
    print(f'Installed {len(sources)} pak files into {paks}')


def uninstall_pak(paks, dry_run):
    """Backs up, then removes the hall lobby pak files in paks (~mods). Silent when none is there."""
    if not (old := [name for name in PAK if (paks / name).is_file()]): return
    if dry_run: return print(f'Dry run: would back up {len(old)} pak files into {BACKUPS} and remove them from {paks}')
    if running_game(): sys.exit(CLOSE_GAME)
    backup(paks, old, 'Paks')
    for name in old:
        (paks / name).unlink()
        print(f'Removed {paks / name}')


def install_ue4ss(win64, files, dry_run):
    """Writes SBO's UE4SS package (tools/ue4ss.py) into win64, SB/Binaries/Win64. It backs up first every file it
    replaces or removes. It removes the signature scripts the package lacks (FText_Constructor.lua, another build's)
    and UE4SS_OLD. A mods.txt already there stays: it lists the player's mods."""
    if (win64 / 'ue4ss/Mods/mods.txt').is_file():
        files = {rel: data for rel, data in files.items() if rel != 'ue4ss/Mods/mods.txt'}
    scripts = {path.relative_to(win64).as_posix() for path in (win64 / 'ue4ss/UE4SS_Signatures').glob('*.lua')}
    gone = sorted((scripts - set(files)) | {rel for rel in UE4SS_OLD if (win64 / rel).is_file()})
    old = sorted({*gone, *(rel for rel in files if (win64 / rel).is_file())})
    if dry_run:
        if old: print(f'Dry run: would back up {len(old)} UE4SS files first')
        for rel in gone: print(f'Dry run: would remove {win64 / rel}')
        return print(f'Dry run: would install {len(files)} UE4SS files into {win64}')
    if running_game(): sys.exit(CLOSE_GAME)
    if old: backup(win64, old, 'Win64')
    for rel in gone:
        print(f'Removing {win64 / rel}')
        (win64 / rel).unlink()
    for rel, data in files.items():
        (win64 / rel).parent.mkdir(parents=True, exist_ok=True)
        (win64 / rel).write_bytes(data)
    print(f'Installed {len(files)} UE4SS files into {win64}')


def changelog(ver, when, subjects):
    """CHANGELOG.md from the commit subjects, newest first: features and fixes only. It goes into the zip, never
    into the repository."""
    sections = {'feat': [], 'fix': []}
    for subject in subjects:
        if match := re.match(r'^(feat|fix)(\(([a-z-]+)\))?(!)?: (.+)$', subject):
            kind, _, scope, breaking, text = match.groups()
            sections[kind].append(f"- {f'{scope}: ' if scope else ''}{text}{' (breaking)' if breaking else ''}")
    day = time.strftime('%Y-%m-%d', time.gmtime(when))
    lines = [f'# StellarCoop {ver}', '', f'Built from the commit of {day}; generated from the commits after 0.9.0.']
    for title, kind in (('Features', 'feat'), ('Fixes', 'fix')):
        if sections[kind]: lines += ['', f'## {title}', *sections[kind]]
    return '\n'.join(lines) + '\n'


DOCS = ('INSTALL.md', 'LICENSE', 'NOTICE', 'EXCLUDED-PARTIES.md')  # Repository files every release zip ships.


def write_zip(path, files, changelog_text, when):
    """The same files, text and commit time give the same bytes: every entry gets the commit's time and one mode, in
    sorted names (writestr with a bare name would stamp the current time)."""
    files = {**{rel: data for rel, data in files.items() if rel != ART},
             **{name: (ROOT / name).read_bytes() for name in DOCS}, 'CHANGELOG.md': changelog_text.encode()}
    files['SHA256SUMS.txt'] = ''.join(f'{hashlib.sha256(data).hexdigest()}  {rel}\n'
                                      for rel, data in sorted(files.items())).encode()
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, 'w') as archive:
        for rel, data in sorted(files.items()):
            entry = zipfile.ZipInfo(f'StellarCoop/{rel}', time.gmtime(when)[:6])
            entry.compress_type, entry.external_attr = zipfile.ZIP_DEFLATED, 0o100644 << 16
            archive.writestr(entry, data)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, default=GAME, help='Stellar Blade folder (default: %(default)s)')
    parser.add_argument('--dry-run', action='store_true',
                        help='Check and build only (with --uninstall: change nothing)')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--zip', nargs='?', const=True, metavar='PATH',
                      help='Check, build and write StellarCoop-<version>.zip with INSTALL.md and CHANGELOG.md '
                           '(default: into build/) instead of installing. Needs a clean tree, no game folder.')
    mode.add_argument('--uninstall', action='store_true',
                      help='Back up the StellarCoop folder into ~/StellarCoop-install-backups, then remove it, and '
                           'the same for the hall lobby pak files in ~mods. No checks or build; saves are never '
                           'touched.')
    mode.add_argument('--pak', type=Path, metavar='DIR',
                      help=f'After the install, also copy {", ".join(PAK)} from DIR into SB/Content/Paks/~mods, '
                           'backing up the ones they replace')
    parser.add_argument('--ue4ss', action='store_true',
                        help="Also install UE4SS v4.0.0 with SBO's build of UE4SS.dll, SBO's settings and the files "
                             "of the game's build (tools/ue4ss.py) into SB/Binaries/Win64, backing up the files it "
                             'replaces. The UE4SS Mods folder may be missing then. Not with --zip or --uninstall')
    args = parser.parse_args(argv)
    if args.ue4ss and (args.zip or args.uninstall):
        parser.error('argument --ue4ss: not allowed with --zip or --uninstall')
    # Only a committed tree: the zip, its version and its changelog all name one commit.
    if args.zip and git('status', '--porcelain'):
        sys.exit('A release zip needs a clean tree: commit first (git status is not empty).')
    win64 = args.game / 'SB/Binaries/Win64'
    mods = win64 / 'ue4ss/Mods'
    if not args.zip and not args.ue4ss and not mods.is_dir(): sys.exit(f'No UE4SS Mods folder at {mods}')
    paks = args.game / 'SB/Content/Paks/~mods'
    if args.uninstall:
        uninstall_pak(paks, args.dry_run)
        return uninstall(mods / 'StellarCoop', args.dry_run)
    if args.pak:  # Before the tests and the build: a wrong folder fails in a second, not after six minutes.
        if not paks.parent.is_dir(): sys.exit(f'No Paks folder at {paks.parent}')
        sources = pak_sources(args.pak)
    if args.ue4ss:  # Also before: an unknown build or a refused zip stops it in a second.
        ue4ss_files = ue4ss.package(win64 / 'SB-Win64-Shipping.exe')
    # The game embeds Lua 5.4.
    side_by_side([lambda t=t: step(['lua5.4', t.relative_to(ROOT)])
                  for t in sorted((ROOT / 'tests/lua').rglob('*_test.lua'))])
    checks = sanitizers()
    side_by_side([lambda t=t: step([sys.executable, t]) for t in sorted((ROOT / 'tests/tools').glob('*_test.py'))])
    told = subprocess.run(['c++', '--version'], capture_output=True)
    compiler = told.stdout.decode() if told is not None else ''
    # Platform-free native code, run on this machine.
    side_by_side([lambda t=t: native_test(t, checks, compiler)
                  for t in sorted((ROOT / 'tests/native').rglob('*_test.cpp'))])
    ver = version()
    print(f'Version: {ver}', flush=True)
    build = ROOT / 'build/windows'
    subprocess.run(['cmake', '-S', ROOT / 'native', '-B', build, '-G', 'Ninja', '-DCMAKE_BUILD_TYPE=Release',
                    f'-DCMAKE_TOOLCHAIN_FILE={TOOLCHAIN}', f'-DSTELLARCOOP_VERSION={ver}'],
                   check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['cmake', '--build', build], check=True)
    files = package(ver, build / 'StellarCoop.dll')
    if args.zip:
        path = ROOT / f'build/StellarCoop-{ver}.zip' if args.zip is True else Path(args.zip)
        when = int(git('log', '-1', '--format=%ct'))
        write_zip(path, files, changelog(ver, when, subjects()), when)
        return print(f'Wrote {path}')
    target = mods / 'StellarCoop'
    if args.dry_run:
        if rels := replaced(target, files): print(f'Dry run: would back up {len(rels)} files first')
        for path in stale(target, files): print(f'Dry run: would remove {path}')
        print(f'Dry run: would install {len(files)} files into {target}')
    else:
        install_files(target, files)
    if args.ue4ss: install_ue4ss(win64, ue4ss_files, args.dry_run)
    if args.pak: install_pak(sources, paks, args.dry_run)


if __name__ == '__main__':
    main()
