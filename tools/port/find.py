#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Finds the addresses of tools/port/signatures.json in an executable of another build by their signatures.

For each entry it prints the address on build 26123051, the kind, the name and one of:
- found and the address in the executable read;
- ambiguous and the number of matches: places where the pattern matches, or for a holder entry, places that hold the
  code it matches;
- missing: the pattern matches nowhere, a field it reads lies outside the file or no place holds a holder's code.
The image entry gives the image base of the PE header. A section entry gives the start of the section that its
"ghidra" text names after "start of". docs/dev/porting.md says how each kind of signature gives its address back.

Run: python3 tools/port/find.py <SB-Win64-Shipping.exe> (exit code 0 only when every entry is found once)"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # python3 -I leaves the script's folder out.
import addresses  # noqa: E402
import make_signatures as ms  # noqa: E402


def locate(image, entry):
    """The addresses entry gives in image: one when it is found, none when it is missing, several when it is
    ambiguous (for a pattern that matches several times, one per match)."""
    if entry['kind'] == 'image':
        return [image.base]
    if entry['kind'] == 'section':
        name = re.match(r'start of (\S+),', entry['ghidra']).group(1)
        return [va for n, va, _, _ in image.sections if n == name]
    at = ms.matches(image, entry)
    return ms.follow(image, entry, at[0]) if len(at) == 1 else at


def report(image, entries):
    """Prints one line per entry of entries found in image, then the counts. Returns the exit code."""
    count = {'found': 0, 'moved': 0, 'ambiguous': 0, 'missing': 0}
    for a, e in entries.items():
        got = locate(image, e)
        if len(got) == 1:
            count['found'] += 1
            count['moved'] += got[0] != int(a, 16)
            state = f'found {got[0]:#x}'
        elif got:
            count['ambiguous'] += 1
            state = f'ambiguous ({len(got)} matches)'
        else:
            count['missing'] += 1
            state = 'missing'
        print(f'{a}  {e["kind"]:<8}  {e.get("name", ""):<24}  {state}')
    print(f'{count["found"]} found ({count["moved"]} moved), {count["ambiguous"]} ambiguous, {count["missing"]} missing')
    return 0 if count['ambiguous'] == count['missing'] == 0 else 1


def main(argv):
    if len(argv) != 2:
        sys.exit(__doc__.rsplit('Run: ', 1)[1])
    return report(ms.Image(Path(argv[1]).read_bytes()), addresses.load())


if __name__ == '__main__':
    sys.exit(main(sys.argv))
