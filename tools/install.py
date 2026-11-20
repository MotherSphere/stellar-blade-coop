#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Checks and builds StellarCoop, then copies it into Stellar Blade's UE4SS Mods folder (never while the game runs).
What an install replaces or removes is backed up first; --uninstall backs up the whole folder, then removes it.
--zip writes a release zip that the same commit always gives byte for byte, with a CHANGELOG.md from the commits made
after the last GPL-3.0 commit. --pak also copies the hall lobby pak, kept on this PC and never in the zip, into
SB/Content/Paks/~mods; --uninstall backs up and removes its three files there, and nothing else in ~mods. --bike also
installs the Fusion Strider dev bike: mod/EveHoverbike, its paks and CPS plugin from a folder kept off the repository,
with SBO's own bike turned off (docs/vehicles/fusion-strider-handover.md)."""
import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile
from fnmatch import fnmatch
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = Path('/mnt/Jeux/SteamLibrary/steamapps/common/StellarBlade')
TOOLCHAIN = os.environ.get('STELLAR_WINDOWS_TOOLCHAIN', str(Path.home() / '.local/share/xwin/clang-cl-msvc.cmake'))
MANIFEST = 'install-manifest.txt'
RUNTIME = ('coop-*.log', 'coop-*.txt', '*.old.log')  # Written by the mod in game: never removed.
OBSOLETE = {'steam-probe.txt'}  # Left by an old probe, before the manifest existed.
BACKUPS = Path.home() / 'StellarCoop-install-backups'  # Outside the game folder: UE4SS would load a copy under Mods.
CLOSE_GAME = 'Close Stellar Blade first: its mods must not change under it.'
# The last commit released under GPL-3.0 (NOTICE): the zip's changelog lists only the commits after it.
LAST_GPL = '051ab5090a2ea6832279345524e9cdaa816ee736'
ART = 'Assets/MotherSphere.png'  # timediffer24's art, not under the SBO License (NOTICE): installed, never zipped.
PAK = ('zSBO_Lobby.pak', 'zSBO_Lobby.ucas', 'zSBO_Lobby.utoc')  # The only files --pak and --uninstall touch in ~mods.
# --bike: the dev bike's paks (each in its own folder under ~mods, as its folder holds them) and its CPS plugin.
BIKE_PAKS = ('EveBike_FusionStrider_P', 'EveBike_FusionRider_P', 'Batcycle_P', 'EvecycleImpact_P')
BIKE_CPS = 'eve_hoverbike.cps'
BIKE_FILES = [Path(n, f'{n}.{ext}') for n in BIKE_PAKS for ext in ('pak', 'ucas', 'utoc')] + [Path(BIKE_CPS)]
# --bike with no folder: those files in one zip on a draft release of Saroj's fork, visible only to its collaborators.
# The GitHub CLI downloads it (gh, logged in with access to the fork); nothing is unpacked unless it hashes like this.
BIKE_KIT = {'repo': 'sarojratul/stellar-blade-coop', 'tag': 'fusion-bike-kit-1', 'file': 'fusion-bike-kit.zip',
            'sha256': 'b8bb77c5599054831e22f8f1a72997948fe02c0cda0145067dc9998851143aa8'}
# Starting files: written only when the player has none, since the mod or its CPS page rewrites them.
BIKE_FIRST = ('Scripts/tuning.txt',)
# Settings --bike writes, backed up first: SBO's own bike off (F3 is Eve Hoverbike's), and UE4SS's game-thread queue
# on ProcessEvent (with EngineTick it never ran on Saroj's PC, where CPS also hooks the engine tick).
BIKE_COOP = (('bike', 'off'), ('bike_key', 'none'))
BIKE_UE4SS = ('DefaultExecuteInGameThreadMethod', 'ProcessEvent')


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
    """Every file the mod folder gets, as {relative path: content}."""
    mod = ROOT / 'mod/StellarCoop'
    files = {p.relative_to(mod).as_posix(): p.read_bytes() for p in sorted(mod.rglob('*')) if p.is_file()}
    files['Scripts/version.lua'] = f"return '{ver}'\n".encode()
    files['StellarCoop.dll'] = dll.read_bytes()
    return files


def stale(target, files):
    """Files of the previous install that this one no longer ships, plus known obsolete ones. Logs always stay."""
    manifest = target / MANIFEST
    old = set(manifest.read_text().splitlines()) if manifest.is_file() else set()
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
    (target / MANIFEST).write_text(''.join(f'{rel}\n' for rel in sorted(files)))
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


def bike_sources(folder):
    """The dev bike's files in folder, relative to it; a folder without one of them is refused."""
    if missing := [p.as_posix() for p in BIKE_FILES if not (folder / p).is_file()]:
        sys.exit(f'No {", ".join(missing)} in {folder}')
    return list(BIKE_FILES)


def bike_kit(dest, download=None):
    """The dev bike's folder from BIKE_KIT: the zip downloaded into dest once (download(dest) fetches it; gh by
    default), refused unless it hashes like BIKE_KIT, then only BIKE_FILES unpacked into dest/<hash>."""
    folder, zipped = dest / BIKE_KIT['sha256'][:16], dest / BIKE_KIT['file']
    if all((folder / p).is_file() for p in BIKE_FILES): return folder
    dest.mkdir(parents=True, exist_ok=True)
    if not zipped.is_file() or sha256(zipped) != BIKE_KIT['sha256']:
        print(f'Downloading {BIKE_KIT["file"]} from {BIKE_KIT["repo"]} ({BIKE_KIT["tag"]})', flush=True)
        try:
            (download or gh_download)(dest)
        except (OSError, subprocess.CalledProcessError) as e:
            sys.exit(f'The dev bike kit did not download ({e}). It needs the GitHub CLI (gh) logged in with access '
                     f'to {BIKE_KIT["repo"]}: ask Saroj to add you, or pass --bike <folder>.')
    if not zipped.is_file() or sha256(zipped) != BIKE_KIT['sha256']:
        sys.exit(f'{zipped} does not hash like the dev bike kit: nothing unpacked')
    with zipfile.ZipFile(zipped) as kit:
        for rel in BIKE_FILES:  # These names only: nothing else in the zip is written.
            (folder / rel).parent.mkdir(parents=True, exist_ok=True)
            (folder / rel).write_bytes(kit.read(rel.as_posix()))
    print(f'Dev bike kit unpacked into {folder}')
    return folder


def gh_download(dest):
    """BIKE_KIT's zip into dest through the GitHub API (a draft release has no tag to download by)."""
    def api(*args, **kw):
        return subprocess.run(['gh', 'api', *args], check=True, capture_output=True, **kw).stdout
    found = api(f'repos/{BIKE_KIT["repo"]}/releases', '--paginate', '--jq',
                f'.[] | select(.tag_name == "{BIKE_KIT["tag"]}") | .assets[] | '
                f'select(.name == "{BIKE_KIT["file"]}") | .id', text=True).split()
    if not found: raise OSError(f'no {BIKE_KIT["file"]} on release {BIKE_KIT["tag"]} visible to this login')
    (dest / BIKE_KIT['file']).write_bytes(api('-H', 'Accept: application/octet-stream',
                                              f'repos/{BIKE_KIT["repo"]}/releases/assets/{found[0]}'))


def set_key(text, key, value, sep):
    """text with its key line set to value (the first one, its separator kept), or added at the end; None when it
    already holds value."""
    line = re.compile(rf'^([ \t]*{re.escape(key)}[ \t]*=[ \t]*)([^\r\n;#]*?)([ \t]*)(?=\r?$)', re.M)
    if m := line.search(text):
        return None if m.group(2) == value else text[:m.start(2)] + value + text[m.end(2):]
    nl = '\r\n' if '\r\n' in text else '\n'
    return text + ('' if not text or text.endswith('\n') else nl) + f'{key}{sep}{value}{nl}'


def write_keys(path, keys, sep, dry_run, add=True):
    """Sets each (key, value) in the text file path, backed up first; a missing file is written with them when add."""
    text = path.read_bytes().decode('utf-8-sig') if path.is_file() else None  # Bytes: its line ends kept.
    if text is None and not add: return print(f'No {path}: set {"; ".join(f"{k}{sep}{v}" for k, v in keys)} by hand')
    new = text or ''
    for key, value in keys:
        if text is not None and not add and not re.search(rf'^[ \t]*{re.escape(key)}[ \t]*=', new, re.M):
            print(f'{path} has no {key} line: add {key}{sep}{value} under its section by hand')
            continue
        new = set_key(new, key, value, sep) or new
    if new == (text or ''): return print(f'{path.name} already holds {", ".join(f"{k}{sep}{v}" for k, v in keys)}')
    if dry_run: return print(f'Dry run: would set {", ".join(f"{k}{sep}{v}" for k, v in keys)} in {path}')
    if text is not None: backup(path.parent, [path.name], path.parent.name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(new.encode('utf-8'))
    print(f'Set {", ".join(f"{k}{sep}{v}" for k, v in keys)} in {path}')


def install_bike(folder, sources, game, dry_run):
    """The Fusion Strider dev bike: mod/EveHoverbike into UE4SS's Mods, its paks into ~mods, its plugin into CPS, its
    starting files where the player has none, SBO's bike off and UE4SS's queue on ProcessEvent. Every file it replaces
    is backed up first."""
    win = game / 'SB/Binaries/Win64'
    if not (win / 'CPS/CPS.dll').is_file():
        sys.exit(f'No CPS at {win / "CPS"}: install CPS (Custom Plugin System) first')
    if running_game() and not dry_run: sys.exit(CLOSE_GAME)
    src, target = ROOT / 'mod/EveHoverbike', win / 'ue4ss/Mods/EveHoverbike'
    files = {p.relative_to(src).as_posix(): p for p in sorted(src.rglob('*'))
             if p.is_file() and p.name != 'cps-settings.json'}
    files = {rel: p for rel, p in files.items() if rel not in BIKE_FIRST or not (target / rel).is_file()}
    copies = [(target, rel, p) for rel, p in files.items()]
    copies += [(game / 'SB/Content/Paks/~mods', rel.as_posix(), folder / rel) for rel in sources[:-1]]
    copies += [(win / 'CPS/Plugins', BIKE_CPS, folder / BIKE_CPS)]
    config = win / 'CPS/Configs/EveHoverbike'
    if not (config / 'settings.json').is_file(): copies.append((config, 'settings.json', src / 'cps-settings.json'))
    if dry_run:
        print(f'Dry run: would install {len(copies)} dev bike files (Eve Hoverbike, {len(BIKE_PAKS)} paks, {BIKE_CPS})')
    else:
        for root in {c[0] for c in copies}:
            old = [rel for r, rel, _ in copies if r == root and (root / rel).is_file()]
            if old: backup(root, old, root.name)
        for root, rel, path in copies:
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, root / rel)
            if sha256(root / rel) != sha256(path): sys.exit(f'{root / rel} does not hash like {path}: run --bike again')
        # Eve Hoverbike writes its button journal, keys_bike.txt and recordings there but never makes the folder.
        (target / 'telemetry').mkdir(parents=True, exist_ok=True)
        print(f'Installed {len(copies)} dev bike files')
    if (win / 'ue4ss/Mods/StellarCoop').is_dir():
        write_keys(win / 'ue4ss/Mods/StellarCoop/coop-settings.txt', BIKE_COOP, '=', dry_run)
    else:
        print('No StellarCoop folder: SBO is not installed, so its bike settings are left for its first start')
    write_keys(win / 'ue4ss/UE4SS-settings.ini', [BIKE_UE4SS], ' = ', dry_run, add=False)


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
    parser.add_argument('--bike-only', action='store_true',
                        help="With --bike: install the dev bike alone. SBO's tests, build and install are skipped and "
                             'its installed files are left as they are (its coop-settings.txt gets the two bike lines)')
    parser.add_argument('--bike', type=Path, nargs='?', const=True, metavar='DIR',
                        help=f'After the install, also install the Fusion Strider dev bike: mod/EveHoverbike, the paks '
                             f'{", ".join(BIKE_PAKS)} (each in its own folder in DIR) and {BIKE_CPS} from DIR, '
                             "with SBO's bike off (docs/vehicles/fusion-strider-handover.md). With no DIR the kit is "
                             f'downloaded from {BIKE_KIT["repo"]} with gh into build/bike-kit')
    args = parser.parse_args(argv)
    if args.bike and (args.zip or args.uninstall): parser.error('--bike goes with an install only')
    if args.bike_only and (not args.bike or args.pak): parser.error('--bike-only goes with --bike alone')
    # Only a committed tree: the zip, its version and its changelog all name one commit.
    if args.zip and git('status', '--porcelain'):
        sys.exit('A release zip needs a clean tree: commit first (git status is not empty).')
    mods = args.game / 'SB/Binaries/Win64/ue4ss/Mods'
    if not args.zip and not mods.is_dir(): sys.exit(f'No UE4SS Mods folder at {mods}')
    paks = args.game / 'SB/Content/Paks/~mods'
    if args.uninstall:
        uninstall_pak(paks, args.dry_run)
        return uninstall(mods / 'StellarCoop', args.dry_run)
    if args.pak:  # Before the tests and the build: a wrong folder fails in a second, not after six minutes.
        if not paks.parent.is_dir(): sys.exit(f'No Paks folder at {paks.parent}')
        sources = pak_sources(args.pak)
    if args.bike is True: args.bike = bike_kit(ROOT / 'build/bike-kit')  # Before the tests and the build too.
    if args.bike: bike = bike_sources(args.bike)
    if args.bike_only: return install_bike(args.bike, bike, args.game, args.dry_run)
    for test in sorted((ROOT / 'tests/lua').rglob('*_test.lua')):
        subprocess.run(['lua5.4', test.relative_to(ROOT)], cwd=ROOT, check=True)  # The game embeds Lua 5.4.
    checks = sanitizers()
    for test in sorted((ROOT / 'tests/tools').glob('*_test.py')):
        subprocess.run([sys.executable, test], cwd=ROOT, check=True)
    for test in sorted((ROOT / 'tests/native').rglob('*_test.cpp')):  # Platform-free native code, run on this machine.
        exe = ROOT / 'build/host' / '_'.join(test.relative_to(ROOT / 'tests/native').with_suffix('').parts)
        subprocess.run(['c++', '-std=c++17', '-Wall', '-Wextra', '-Werror', *checks, '-I', ROOT / 'native/src', test,
                        '-o', exe], check=True)
        subprocess.run([exe], check=True)
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
    if args.pak: install_pak(sources, paks, args.dry_run)
    if args.bike: install_bike(args.bike, bike, args.game, args.dry_run)


if __name__ == '__main__':
    main()
