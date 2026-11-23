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
Then the same report for tools/port/ue4ss.json (the addresses that UE4SS's signature scripts find) and the text of a
UE4SS_Signatures/<name>.lua for each one (docs/dev/ue4ss.md).

Run: python3 tools/port/find.py <SB-Win64-Shipping.exe> (exit code 0 only when every entry is found once and every
UE4SS target gets a script)"""
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


HEADER = """-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""


def script(image, entry):
    """The text of UE4SS_Signatures/<name>.lua that gives entry's address in image, or None when its signature cannot
    serve: it is not found once, it also matches outside the code (UE4SS scans the whole image), or it needs a holder
    or an 8-byte read (a script reads with DerefToInt32 only)."""
    got, ref, steps = locate(image, entry), entry.get('ref'), []
    pattern = bytes.fromhex(entry['pattern'].replace('??', '00'))
    # shortcut: the file's bytes only; a match in data the game writes at run time is not seen. A game test shows it.
    hits = sum(len(ms.find(blob, pattern, entry['mask'], 2)) for _, _, blob, _ in image.sections)
    while ref and not ref.get('read'):
        add = f' + {ref["add"]}' if ref['add'] else ''
        steps.append(f'    Address = Address + {ref["end"]} + DerefToInt32(Address + {ref["disp"]}){add}')
        ref = ref.get('then')
    if len(got) != 1 or hits != 1 or ref or 'holder' in entry:
        return None
    return HEADER + '\n'.join([
        f'-- UE4SS_Signatures/{entry["name"]}.lua: {entry["name"]} at {got[0]:#x} in the Stellar Blade executable with',
        f'-- TimeDateStamp {image.stamp:#x} and SizeOfImage {image.size:#x}. Written by tools/port/find.py from the',
        '-- signature in tools/port/ue4ss.json. Read the address in Ghidra before it ships.',
        'function Register()', f'    return "{entry["pattern"]}"', 'end', '', 'function OnMatchFound(MatchAddress)',
        '    local Address = MatchAddress', *steps, '    return Address', 'end', ''])


def ue4ss(image, targets):
    """Prints the report of targets (tools/port/ue4ss.json), then a UE4SS signature script for each one or a line that
    says it has none. Returns the exit code: 0 when each target got a script."""
    print(f'UE4SS signature targets ({addresses.UE4SS.name}):')
    code = report(image, targets)
    for e in targets.values():
        text = script(image, e)
        print(text or f'UE4SS_Signatures/{e["name"]}.lua: no script. Find the address in Ghidra, then write the '
                      'script by hand.')
        code |= text is None
    return code


def main(argv):
    if len(argv) != 2:
        sys.exit(__doc__.rsplit('Run: ', 1)[1])
    image = ms.Image(Path(argv[1]).read_bytes())
    return report(image, addresses.load()) | ue4ss(image, addresses.load(addresses.UE4SS))


if __name__ == '__main__':
    sys.exit(main(sys.argv))
