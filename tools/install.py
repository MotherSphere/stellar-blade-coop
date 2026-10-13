#!/usr/bin/env python3
"""Checks and builds StellarCoop, then copies it into Stellar Blade's UE4SS Mods folder (never while the game runs)."""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = Path('/mnt/Jeux/SteamLibrary/steamapps/common/StellarBlade')
TOOLCHAIN = os.environ.get('STELLAR_WINDOWS_TOOLCHAIN', str(Path.home() / '.local/share/xwin/clang-cl-msvc.cmake'))


def running_game():
    for path in Path('/proc').glob('[0-9]*/comm'):
        try:
            if path.read_text().strip().startswith('SB-Win64'): return True
        except OSError: pass
    return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, default=GAME, help='Stellar Blade folder (default: %(default)s)')
    parser.add_argument('--dry-run', action='store_true', help='Check and build only')
    args = parser.parse_args()
    mods = args.game / 'SB/Binaries/Win64/ue4ss/Mods'
    if not mods.is_dir(): sys.exit(f'No UE4SS Mods folder at {mods}')
    for test in sorted((ROOT / 'tests').glob('*_test.lua')):
        subprocess.run(['lua', test.relative_to(ROOT)], cwd=ROOT, check=True)
    build = ROOT / 'build/windows'
    subprocess.run(['cmake', '-S', ROOT / 'native', '-B', build, '-G', 'Ninja', '-DCMAKE_BUILD_TYPE=Release',
                    f'-DCMAKE_TOOLCHAIN_FILE={TOOLCHAIN}'], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['cmake', '--build', build], check=True)
    target = mods / 'StellarCoop'
    if args.dry_run: return print(f'Dry run: would install into {target}')
    if running_game(): sys.exit('Close Stellar Blade first: its mods must not change under it.')
    shutil.copytree(ROOT / 'mod/StellarCoop', target, dirs_exist_ok=True)
    shutil.copy2(build / 'StellarCoop.dll', target / 'StellarCoop.dll')
    print(f'Installed into {target}')


if __name__ == '__main__':
    main()
