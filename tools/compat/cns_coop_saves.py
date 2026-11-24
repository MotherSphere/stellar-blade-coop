#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Lets the Custom Nanosuit System (CNS, DekitaRPG's mod) see the outfits unlocked on SBO's co-op saves.
CNS reads StellarBladeSave00.sav by name for its unlock check. This tool inserts two blocks of SBO's code into CNS's
ue4ss/Mods/DekCNS/Scripts/main.lua. The first falls back to StellarBladeCoop00.sav when there is no solo save. The
second runs CNS's own loader on both saves and keeps the outfits either one unlocks. It removes no line of CNS.
It changes only a main.lua whose SHA-256 it knows, never while the game runs. It backs the file up into
~/StellarCoop-install-backups first. --check changes nothing. --remove gives back CNS's file byte for byte.
It never opens a save for writing. The cause, the first patch and its game test are Schizo-Effective23's (pull
request 8). This repository holds no code of CNS: only the names of its functions and variables.
Run: python3 -I tools/compat/cns_coop_saves.py [--game DIR] [--check | --remove]"""
import argparse
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))  # python3 -I leaves the script's folders out.
import install  # noqa: E402

CNS = Path('SB/Binaries/Win64/ue4ss/Mods/DekCNS/Scripts/main.lua')
BEGIN, END = b'-- SBO co-op saves: begin', b'-- SBO co-op saves: end'

# Goes after the solo save check in ResolveSaveFilePath, inside the block where CNS's locals path, savedDir and steamId
# are set. Schizo-Effective23's first patch (2026-11-15), here built from path.
FALLBACK = b'''\
            -- SBO co-op saves: begin
            -- No solo save: try the co-op copy in the same folder (Schizo-Effective23, 2026-11-15).
            local coop = path:gsub("StellarBladeSave00%.sav$", "StellarBladeCoop00.sav")
            local coopFile = io.open(coop, "rb")
            if coopFile then
                coopFile:close()
                ResolvedSaveFilePath = coop
                return coop
            end
            -- SBO co-op saves: end
'''

# Goes right after LoadOutfitKeysFromSaveFile. CNS's loader reads the file ResolvedSaveFilePath names and caches what
# it finds in CachedOutfitsFromSaveFile. The wrapper runs it on each save that opens and caches the union.
UNION = b'''\
-- SBO co-op saves: begin
-- With SBO's co-op saves on, the game plays from StellarBladeCoop00.sav, so an outfit can be unlocked in either save.
-- Run the loader above on the save it resolved, then on its twin (Save00 or Coop00) when that file opens.
-- Keep an outfit as unlocked when either run has it.
do
    local loadOne = LoadOutfitKeysFromSaveFile
    LoadOutfitKeysFromSaveFile = function()
        if CachedOutfitsFromSaveFile ~= nil then return CachedOutfitsFromSaveFile end
        local union = {}
        for key, unlocked in pairs(loadOne()) do union[key] = unlocked end
        local first = ResolvedSaveFilePath
        if first then
            local twin = first:gsub("StellarBladeSave00%.sav$", "StellarBladeCoop00.sav")
            if twin == first then twin = first:gsub("StellarBladeCoop00%.sav$", "StellarBladeSave00.sav") end
            local twinFile = twin ~= first and io.open(twin, "rb")
            if twinFile then
                twinFile:close()
                ResolvedSaveFilePath, CachedOutfitsFromSaveFile = twin, nil
                for key, unlocked in pairs(loadOne()) do union[key] = union[key] or unlocked end
                ResolvedSaveFilePath = first
            end
        end
        CachedOutfitsFromSaveFile = union
        return union
    end
end
-- SBO co-op saves: end
'''
BLOCKS = (FALLBACK, UNION)

# The CNS files this tool knows: SHA-256 of the shipped main.lua, its CNS version, the line each block goes after.
KNOWN = {
    # CNS v2.2, 1083 lines. 116: the end of ResolveSaveFilePath's solo save check (inside its savedDir
    # block). 160: the end of LoadOutfitKeysFromSaveFile.
    'e4b44a7e892cfe95896f4add3730bbc9f6cf2c47035335526a9e415dc813299e': ('2.2', (116, 160)),
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def strip(data):
    """data without the lines from each begin marker to its end marker, the markers included."""
    kept, inside = [], False
    for line in data.splitlines(keepends=True):
        mark = line.strip()
        if mark == BEGIN: inside = True
        if not inside: kept.append(line)
        if mark == END: inside = False
    return b''.join(kept)


def insert(original, points):
    """original with each block after its line, counted in original."""
    lines = original.splitlines(keepends=True)
    for after, block in sorted(zip(points, BLOCKS), reverse=True):  # From the end: the earlier numbers stay right.
        lines[after:after] = [block]
    return b''.join(lines)


def read(path, known):
    """(path's bytes, those bytes without the blocks, (CNS version, points) or None)."""
    data = path.read_bytes()
    original = strip(data)
    return data, original, known.get(digest(original))


def refuse(path, data, known):
    versions = ', '.join(f'v{version}' for version, _ in known.values())
    sys.exit(f'{path} is not a CNS main.lua this tool knows (SHA-256 {digest(data)}). It knows CNS {versions}. '
             'Nothing was changed.')


def write(path, data):
    """Backs path up, then writes data into it. Never while the game runs."""
    if install.running_game(): sys.exit(install.CLOSE_GAME)
    install.backup(path.parent, [path.name], 'DekCNS')
    path.write_bytes(data)


def shipped_backup(known):
    """The newest backup of a main.lua this tool knows as shipped, or None."""
    for copy in sorted(install.BACKUPS.glob('*/DekCNS/main.lua'), reverse=True):
        if digest(copy.read_bytes()) in known: return copy
    return None


def check(path, known):
    data, original, found = read(path, known)
    if not found: refuse(path, data, known)
    if data == original: return print(f'{path}: CNS v{found[0]} as shipped. The co-op saves change is not applied.')
    if data == insert(original, found[1]): return print(f'{path}: CNS v{found[0]} with the co-op saves change.')
    print(f'{path}: CNS v{found[0]} with other co-op saves blocks (edited, or from another version of this tool). '
          'Applying writes the current blocks. --remove takes them out.')


def apply(path, known):
    data, original, found = read(path, known)
    if not found: refuse(path, data, known)
    patched = insert(original, found[1])
    if data == patched: return print(f'{path}: the co-op saves change is already applied. Nothing was changed.')
    write(path, patched)
    print(f'Applied the co-op saves change to CNS v{found[0]} in {path}')


def remove(path, known):
    data, original, found = read(path, known)
    if data == original:
        if not found: refuse(path, data, known)
        return print(f'{path}: CNS v{found[0]} as shipped. Nothing to remove.')
    if found:
        write(path, original)
        return print(f'Removed the co-op saves change: {path} is CNS v{found[0]} as shipped again.')
    # Without the blocks, the file does not hash as shipped: a line of CNS changed after the blocks went in.
    copy = shipped_backup(known)
    if copy is None:
        sys.exit(f'{path} without the co-op saves blocks is not a CNS main.lua this tool knows. {install.BACKUPS} '
                 'has no shipped copy of it. Nothing was changed. Reinstall CNS.')
    write(path, copy.read_bytes())
    sys.exit(f'{path} without the co-op saves blocks did not hash as shipped: restored CNS\'s file from {copy}. The '
             'file as it was is in the newest backup.')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--game', type=Path, default=install.GAME, help='Stellar Blade folder (default: %(default)s)')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true', help="Say which state CNS's main.lua is in. Change nothing")
    mode.add_argument('--remove', action='store_true', help="Take the two blocks out again, after a backup")
    args = parser.parse_args(argv)
    path = args.game / CNS
    if not path.is_file(): sys.exit(f'No CNS main.lua at {path}')
    (check if args.check else remove if args.remove else apply)(path, KNOWN)


if __name__ == '__main__':
    main()
