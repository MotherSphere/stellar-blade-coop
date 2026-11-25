#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""SBO's UE4SS package: the official UE4SS v4.0.0 release with SBO's build of UE4SS.dll, Stellar Blade Online's
settings and the files of one Stellar Blade build, as paths under SB/Binaries/Win64.

fetch() downloads the release zip once into CACHE. It refuses bytes whose SHA-256 is not SHA256, from the cache or
from the download. The zip is only read as data: nothing in it runs here.
package() takes the release's dwmapi.dll and ue4ss/ folder without its settings file and without the example mods
that change the game (DROPPED, whose lines also leave mods.txt). Its UE4SS.dll is SBO's build (DLL by default): tag
v4.0.0 with the patch in ue4ss/patches/, which tools/ue4ss_build.py applies and builds. That patch fixes the freeze
of UE4SS-RE/RE-UE4SS issue 1504. A file whose SHA-256 is not DLL_SHA256 is refused before any download. The release's
UE4SS.dll is not shipped. package() swaps in SBO's UEHelpers.lua (HELPERS). It adds
ue4ss/UE4SS-settings.ini, the files of ue4ss/builds/<TimeDateStamp>-<SizeOfImage>/ for the executable's PE header
(the set's README.md stays here) and SBO's NOTICE and LICENSE as ue4ss/SBO-NOTICE and ue4ss/SBO-LICENSE. An
executable with no set gets nothing at all, not even a download: UE4SS v4.0.0 without the set's
MemberVariableLayout.ini writes past the end of the game's FUObjectArray.

The zip leaves ue4ss/Mods/mods.txt out, so a player's own list stays. Each mod the release's mods.txt turns on
(BPML_GenericFunctions, BPModLoaderMod, ConsoleEnablerMod, Keybinds) gets an enabled.txt instead, so it also starts on
a game that never had UE4SS. LineTraceMod ships off, as in the release. ConsoleEnablerMod adds F10 and Tilde to the
game's console keys: players type SBO's coop commands in that console.

Run: python3 tools/ue4ss.py fetch
     python3 tools/ue4ss.py zip <SB-Win64-Shipping.exe> <out.zip> [<UE4SS.dll>]
     (paths under SB/Binaries/Win64/, to unpack into the Stellar Blade folder. Without <UE4SS.dll> it takes the
     default output of tools/ue4ss_build.py)"""
import hashlib
import io
import struct
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILDS = ROOT / 'ue4ss/builds'
# The release asset of tag v4.0.0 (commit 30afe5ff), 8758673 bytes. SHA256 is GitHub's digest of it.
URL = 'https://github.com/UE4SS-RE/RE-UE4SS/releases/download/v4.0.0/UE4SS_v4.0.0.zip'
SHA256 = '251ad0d1381a241750e036f5918cbf2b5d7ec58ebc608cb2dd09d459d0c81e45'
CACHE = Path.home() / '.cache/sbo-ue4ss/official-v4.0.0/UE4SS_v4.0.0.zip'
# SBO's UE4SS.dll, where tools/ue4ss_build.py writes it by default, 27089920 bytes. DLL_SHA256 is the build that was
# tested in game: no freeze with a mod that loads assets from a hook, F10 opens the console. It was built by hand from
# commit 9a61a393. tools/ue4ss_build.py builds commit 4c8e4f4d of the same tree: its DLL is not this pin and is refused.
DLL = Path.home() / '.cache/sbo-ue4ss/ue4ss-build/build-rel/Game__Shipping__Win64/bin/UE4SS.dll'
DLL_SHA256 = '791a90ea71c6ffb3743d34f8c1afb239c201984de177286b25ba853e5a1e876b'
# The release's example mods that change the game: cheats, the console's set and summon commands, split screen. A
# player's own copies stay: install.py never touches a mod folder the package lacks. ConsoleEnablerMod ships: SBO's
# coop commands are typed in the console it opens.
DROPPED = ('CheatManagerEnablerMod', 'ConsoleCommandsMod', 'SplitScreenMod')
# SBO's copy of the release's UEHelpers.lua: GetPlayerController and GetWorld keep what they found while it stays valid.
HELPERS = 'ue4ss/Mods/shared/UEHelpers/UEHelpers.lua'


def build(exe):
    """The executable's set name: its PE TimeDateStamp and SizeOfImage in lower-case hex, the two values that
    check_build() in native/src/game/partner/engine.h pins (6ad8eff1-15fa3000 for build 26123051)."""
    try:
        with open(exe, 'rb') as data:
            head = data.read(4096)
    except OSError as error:
        sys.exit(f'Cannot read {exe}: {error.strerror}')
    try:
        pe = struct.unpack_from('<I', head, 0x3c)[0]
        if head[:2] == b'MZ' and head[pe:pe + 4] == b'PE\0\0' and struct.unpack_from('<H', head, pe + 24)[0] == 0x20b:
            # COFF header at pe + 4: TimeDateStamp at its +4. Optional header at pe + 24: SizeOfImage at its +56.
            return f'{struct.unpack_from("<I", head, pe + 8)[0]:08x}-{struct.unpack_from("<I", head, pe + 80)[0]:08x}'
    except struct.error:
        pass
    sys.exit(f'{exe} is not a 64-bit Windows executable')


def fetch():
    """The release zip's bytes: CACHE's once it holds them, else downloaded from URL into CACHE."""
    if CACHE.is_file():
        source, data = CACHE, CACHE.read_bytes()
    else:
        print(f'Downloading {URL}', flush=True)
        try:
            with urllib.request.urlopen(URL, timeout=300) as response:
                source, data = URL, response.read()
        except OSError as error:
            sys.exit(f'Cannot download {URL}: {error}')
    if (got := hashlib.sha256(data).hexdigest()) != SHA256:
        sys.exit(f'{source} is not the UE4SS v4.0.0 release zip (SHA-256 {got}, expected {SHA256}): refused')
    if source == URL:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        part = CACHE.with_name(CACHE.name + '.part')
        part.write_bytes(data)
        part.replace(CACHE)  # A write cut short never sits under the cache's name.
    return data


def built(dll):
    """The bytes of SBO's UE4SS.dll at dll. Any other file is refused."""
    try:
        data = Path(dll).read_bytes()
    except OSError as error:
        sys.exit(f'Cannot read {dll}: {error.strerror}. Build it with python3 tools/ue4ss_build.py. '
                 'Nothing was written.')
    if (got := hashlib.sha256(data).hexdigest()) != DLL_SHA256:
        sys.exit(f"{dll} is not SBO's build of UE4SS.dll (SHA-256 {got}, expected {DLL_SHA256}): refused. "
                 'Nothing was written.')
    return data


def package(exe, dll=None):
    """{path under SB/Binaries/Win64: bytes} of SBO's UE4SS for this executable, with the UE4SS.dll at dll (DLL by
    default)."""
    name, sets = build(exe), sorted(p.name for p in BUILDS.iterdir())
    if name not in sets:
        sys.exit(f'SBO has no UE4SS files for this Stellar Blade build ({name}), only for {", ".join(sets)}. '
                 'SBO waits for an update. Nothing was written.')
    ue4ss_dll = built(dll or DLL)  # Before the download: a missing or wrong DLL stops it in a second.
    release, dropped = zipfile.ZipFile(io.BytesIO(fetch())), tuple(f'ue4ss/Mods/{mod}/' for mod in DROPPED)
    files = {entry.filename: release.read(entry) for entry in release.infolist() if not entry.is_dir()
             and entry.filename != 'ue4ss/UE4SS-settings.ini' and not entry.filename.startswith(dropped)}
    listed = files['ue4ss/Mods/mods.txt'].decode('utf-8').splitlines(keepends=True)
    files['ue4ss/Mods/mods.txt'] = ''.join(ln for ln in listed if ln.split(':')[0].strip() not in DROPPED).encode()
    # The zip has no mods.txt: each mod the release's mods.txt turns on gets an enabled.txt, so it starts on a game
    # that never had UE4SS too (BPModLoaderMod loads the Blueprint mods).
    for line in listed:
        mod, _, on = (part.strip() for part in line.partition(':'))
        if on == '1' and mod not in DROPPED and any(f.startswith(f'ue4ss/Mods/{mod}/') for f in files):
            files[f'ue4ss/Mods/{mod}/enabled.txt'] = b''
    files['ue4ss/UE4SS.dll'] = ue4ss_dll  # In place of the release's.
    files['ue4ss/UE4SS-settings.ini'] = (ROOT / 'ue4ss/UE4SS-settings.ini').read_bytes()
    files[HELPERS] = (ROOT / HELPERS).read_bytes()  # The release's file with the caches of UE4SS 3.x put back.
    for path in sorted((BUILDS / name).rglob('*')):
        if path.is_file() and path.name != 'README.md':
            files[f'ue4ss/{path.relative_to(BUILDS / name).as_posix()}'] = path.read_bytes()
    files['ue4ss/SBO-NOTICE'] = (ROOT / 'NOTICE').read_bytes()
    files['ue4ss/SBO-LICENSE'] = (ROOT / 'LICENSE').read_bytes()
    return files


def write_zip(files, out):
    """The package as a zip of paths under SB/Binaries/Win64/. The same files give the same bytes: every entry gets
    one time and one mode, in sorted names."""
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, 'w') as archive:
        for rel, data in sorted(files.items()):
            entry = zipfile.ZipInfo(f'SB/Binaries/Win64/{rel}', (1980, 1, 1, 0, 0, 0))
            entry.compress_type, entry.external_attr = zipfile.ZIP_DEFLATED, 0o100644 << 16
            archive.writestr(entry, data)


def main(argv):
    if argv[1:] == ['fetch']:
        fetch()
        return print(f'{CACHE}: UE4SS v4.0.0, SHA-256 checked')
    if len(argv) in (4, 5) and argv[1] == 'zip':
        # Unpacked over a UE4SS install, a mods.txt would replace the player's list of mods: install.py keeps it too.
        files = {rel: data for rel, data in package(argv[2], *argv[4:]).items() if rel != 'ue4ss/Mods/mods.txt'}
        write_zip(files, Path(argv[3]))
        return print(f'Wrote {argv[3]} ({len(files)} files)')
    sys.exit(__doc__.rsplit('Run: ', 1)[1])


if __name__ == '__main__':
    main(sys.argv)
