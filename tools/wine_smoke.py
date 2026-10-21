#!/usr/bin/env python3
"""Wine smoke test: builds StellarCoop.dll and tests/wine/smoke.exe, then loads the DLL under Proton's wine in a scratch
WINEPREFIX with no steam_api64.dll around. Checks that it attaches, waits for Steam, answers coop_tick when exported,
says pilot=refused for same-place enemies, refuses the Night Operation poller, the shared fight's probe, a pilot test,
the force target test, coop freeze and the save name's probe on an exe that is not the game but takes coop fight pilot off, logs the save name's state (off) once, and logs a clean process exit; that ReadProcessMemory behaves as
the poller needs; and that the copy request's clipboard call is read back. Runs with no display, so the clipboard
stays inside wine and the desktop's is never touched. Never touches the game folder or the game's prefix."""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import install  # noqa: E402  Same root, toolchain and version as the installer's build.

ROOT = install.ROOT
XWIN = Path.home() / '.local/share/xwin'  # The toolchain file's default XWIN_ROOT.
WINE = Path.home() / ('.local/share/Steam/compatibilitytools.d/proton-cachyos-11.0-20261005-slr-x86_64_v3/'
                      'files/bin/wine')
OUT = ROOT / 'build/wine'


def build_dll():
    """build/windows, configured and built exactly like install.py does it."""
    build = ROOT / 'build/windows'
    subprocess.run(['cmake', '-S', ROOT / 'native', '-B', build, '-G', 'Ninja', '-DCMAKE_BUILD_TYPE=Release',
                    f'-DCMAKE_TOOLCHAIN_FILE={install.TOOLCHAIN}', f'-DSTELLARCOOP_VERSION={install.version()}'],
                   check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['cmake', '--build', build], check=True)
    return build / 'StellarCoop.dll'


def build_smoke():
    """smoke.exe with the DLL's compiler and xwin sysroot, static CRT like the DLL."""
    OUT.mkdir(parents=True, exist_ok=True)
    includes = ('crt/include', 'sdk/include/ucrt', 'sdk/include/um', 'sdk/include/shared')
    libs = ('crt/lib/x86_64', 'sdk/lib/um/x86_64', 'sdk/lib/ucrt/x86_64')
    subprocess.run(['clang-cl', '--target=x86_64-pc-windows-msvc', '/std:c++17', '/O2', '/MT', '/EHsc', '/W4', '/WX',
                    *(f'/imsvc{XWIN / d}' for d in includes), f'/I{ROOT / "native/src"}', ROOT / 'tests/wine/smoke.cpp',
                    f'/Fo{OUT / "smoke.obj"}', f'/Fe{OUT / "smoke.exe"}', '-fuse-ld=lld',
                    '/link', *(f'/libpath:{XWIN / d}' for d in libs)], check=True)
    return OUT / 'smoke.exe'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prefix', type=Path, default=OUT / 'prefix',
                        help='Scratch WINEPREFIX, created when missing (default: %(default)s). Never the game\'s.')
    parser.add_argument('--wine', type=Path, default=WINE, help='wine binary (default: %(default)s)')
    args = parser.parse_args()
    prefix = args.prefix.resolve()
    if 'compatdata' in prefix.parts: sys.exit(f'Refusing {prefix}: that looks like a Steam game prefix.')

    dll, exe = build_dll(), build_smoke()
    run = OUT / 'run'  # Fresh each time; kept afterwards so its coop-link.log can be read.
    shutil.rmtree(run, ignore_errors=True)
    run.mkdir(parents=True)
    for path in (dll, exe): shutil.copy2(path, run)
    if any(run.glob('steam_api*.dll')): sys.exit('steam_api64.dll must be absent from the run folder.')

    # mscoree/mshtml off: no Mono or Gecko install prompt while the prefix is created. No DISPLAY or WAYLAND_DISPLAY:
    # with one, wine would hand the test's clipboard text to the desktop and drop what was there.
    env = {k: v for k, v in os.environ.items() if k not in ('DISPLAY', 'WAYLAND_DISPLAY')}
    env.update(WINEPREFIX=str(prefix), WINEDEBUG='-all', WINEDLLOVERRIDES='mscoree,mshtml=')
    if not (prefix / 'system.reg').is_file():
        prefix.parent.mkdir(parents=True, exist_ok=True)
        print(f'Creating the scratch prefix {prefix}', flush=True)
        subprocess.run([args.wine, 'wineboot', '-i'], env=env, check=True, timeout=300,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    folder = 'Z:' + str(run).replace('/', '\\')  # Wine maps / to Z: in every new prefix.
    try:
        result = subprocess.run([args.wine, run / 'smoke.exe', folder], env=env, timeout=60, capture_output=True,
                                text=True)
    except subprocess.TimeoutExpired:
        subprocess.run([args.wine.parent / 'wineserver', '-k'], env=env)  # Never leave a hung smoke.exe behind.
        sys.exit('FAIL: smoke.exe did not exit within 60 s')
    print(result.stdout.strip() or '(smoke.exe printed nothing)')

    log = (run / 'coop-link.log').read_text(errors='replace').splitlines() if (run / 'coop-link.log').is_file() else []
    checks = {
        'smoke.exe exit code 0 (load, steam=waiting, fight=off, pilot=refused and the engine refusing smoke.exe within '
        '3 s, no steam_api64.dll, coop_tick exported and returning 0, nightop, fight probe, pilot test, pilot test '
        'target, freeze and '
        'saves probe refused and pilot off taken within 3 s each, ReadProcessMemory reading its stack and refusing 0x1000, a join code read back from the '
        'clipboard)':
            result.returncode == 0,
        'no nightop-probe.txt in the run folder (the poller never started)':
            not (run / 'nightop-probe.txt').exists(),
        'coop-link.log says "save name: saves=off (build stamp ..." once (each change of the name logged once)':
            sum('save name: saves=off (build stamp' in line for line in log) == 1,
        'coop-link.log ends with "worker stopped: process exit"':
            bool(log) and log[-1].endswith('worker stopped: process exit'),
    }
    for text, ok in checks.items(): print(f'{"ok  " if ok else "FAIL"} {text}')
    if not all(checks.values()):
        print(f'smoke.exe exit code: {result.returncode}; stderr: {result.stderr.strip() or "none"}; coop-link.log:',
              *log, sep='\n  ')
        sys.exit(1)
    print(f'Wine smoke test passed ({args.wine.parent.parent.parent.name}, prefix {prefix})')


if __name__ == '__main__':
    main()
