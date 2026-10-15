#!/usr/bin/env python3
"""Checks and builds StellarCoop, then copies it into Stellar Blade's UE4SS Mods folder (never while the game runs).
What an install replaces or removes is backed up first; --uninstall backs up the whole folder, then removes it."""
import argparse
import hashlib
import os
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


def running_game():
    for path in Path('/proc').glob('[0-9]*/comm'):
        try:
            if path.read_text().strip().startswith('SB-Win64'): return True
        except OSError: pass
    return False


def version():
    try:
        return subprocess.run(['git', 'describe', '--tags', '--always', '--dirty'], cwd=ROOT, capture_output=True,
                              text=True, check=True).stdout.strip() or 'dev'
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


def backup(target, rels):
    """Copies these files of target into a new BACKUPS/<UTC time>[-n]/StellarCoop and returns that folder."""
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
    dest /= 'StellarCoop'
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
    print('Saves, the co-op save slot and StellarCoopSlot.txt are never touched (INSTALL.md: Co-op save slot).')


def write_zip(path, files):
    files = {**files, 'INSTALL.md': (ROOT / 'INSTALL.md').read_bytes()}
    files['SHA256SUMS.txt'] = ''.join(f'{hashlib.sha256(data).hexdigest()}  {rel}\n'
                                      for rel, data in sorted(files.items())).encode()
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as archive:
        for rel, data in sorted(files.items()):
            archive.writestr(f'StellarCoop/{rel}', data)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, default=GAME, help='Stellar Blade folder (default: %(default)s)')
    parser.add_argument('--dry-run', action='store_true',
                        help='Check and build only (with --uninstall: change nothing)')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--zip', nargs='?', const=True, metavar='PATH',
                      help='Check, build and write StellarCoop-<version>.zip (default: into build/) instead of '
                           'installing. Needs no game folder.')
    mode.add_argument('--uninstall', action='store_true',
                      help='Back up the StellarCoop folder into ~/StellarCoop-install-backups, then remove it. No '
                           'checks or build; saves are never touched.')
    args = parser.parse_args(argv)
    mods = args.game / 'SB/Binaries/Win64/ue4ss/Mods'
    if not args.zip and not mods.is_dir(): sys.exit(f'No UE4SS Mods folder at {mods}')
    if args.uninstall: return uninstall(mods / 'StellarCoop', args.dry_run)
    for test in sorted((ROOT / 'tests').glob('*_test.lua')):
        subprocess.run(['lua5.4', test.relative_to(ROOT)], cwd=ROOT, check=True)  # The game embeds Lua 5.4.
    checks = sanitizers()
    for test in sorted((ROOT / 'tests').glob('*_test.py')):
        subprocess.run([sys.executable, test], cwd=ROOT, check=True)
    for test in sorted((ROOT / 'tests').glob('*_test.cpp')):  # Platform-free native code, run on this machine.
        exe = ROOT / 'build/host' / test.stem
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
        write_zip(path, files)
        return print(f'Wrote {path}')
    target = mods / 'StellarCoop'
    if args.dry_run:
        if rels := replaced(target, files): print(f'Dry run: would back up {len(rels)} files first')
        for path in stale(target, files): print(f'Dry run: would remove {path}')
        return print(f'Dry run: would install {len(files)} files into {target}')
    install_files(target, files)


if __name__ == '__main__':
    main()
