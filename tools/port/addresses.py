#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Every address of the game that the native part uses in its code, read from the sources of native/src.

An address is a hex literal outside comments and strings from the image base 0x140000000 up to 512 MB further, or a
constant whose name ends in Rva (added to the image base). Each use gets the name it has in the code: the constant
(kSave), the table entry (kSlots[1]) or the struct field position in a table (kKinds[0][2]). A literal outside a
declaration is named "?".

tools/port/signatures.json holds one entry per address, with what Ghidra shows there on the pinned build. This tool
prints every use with its entry's kind, then the addresses the file lacks and the entries no code uses.
Run: python3 tools/port/addresses.py (exit code 1 when the file and the code differ)"""
import json
import re
import sys
from collections import namedtuple
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / 'native/src'
SIGNATURES = Path(__file__).with_name('signatures.json')
IMAGE_BASE = 0x140000000
SPAN = 0x20000000  # Build 26123051's image is 0x15fa3000 bytes (kSizeOfImage); the margin covers a bigger build.
SUFFIXES = ('.h', '.cpp', '.inc')

Use = namedtuple('Use', 'address name file line')


# Comments, raw strings, strings and character literals. A quote after a digit is a digit separator (0x1'0000).
NOT_CODE = re.compile(r'//[^\n]*|/\*.*?\*/|(?<!\w)R"([^(\s]*)\(.*?\)\1"|"(?:\\.|[^"\\\n])*"'
                      r"|(?<!\w)'(?:\\.|[^'\\\n])*'", re.S)


def blank(text):
    """The text with comments, strings and character literals turned into spaces; line ends stay where they were."""
    return NOT_CODE.sub(lambda m: re.sub(r'[^\n]', ' ', m.group()), text)


def name_at(code, pos):
    """The declared name of the literal at pos: kName for kName = 0x..., kTable[i] or kTable[i][j] inside a braced
    initializer, else '?'."""
    scalar = re.search(r'(\w+)\s*=\s*$', code[max(pos - 200, 0):pos])
    if scalar:
        return scalar.group(1)
    head = code[code.rfind(';', 0, pos) + 1:pos]
    table = None
    for table in re.finditer(r'(\w+)\s*(?:\[[^\]]*\])?\s*=\s*\{', head):
        pass
    if not table:
        return '?'
    path, parens = [0], 0
    for c in head[table.end():]:
        if c == '(':
            parens += 1
        elif c == ')':
            parens -= 1
        elif parens:
            continue
        elif c == '{':
            path.append(0)
        elif c == '}':
            path.pop()
        elif c == ',':
            path[-1] += 1
    return table.group(1) + ''.join(f'[{i}]' for i in path)


def scan(root=SOURCES):
    """The uses of game addresses in the C++ files under root, in file and line order."""
    uses = []
    for path in sorted(p for p in Path(root).rglob('*') if p.suffix in SUFFIXES):
        code = blank(path.read_text(encoding='utf-8'))
        for m in re.finditer(r"\b0[xX]([0-9a-fA-F']+)", code):
            value = int(m.group(1).replace("'", ''), 16)
            if value < SPAN and re.search(r'Rva\s*=\s*$', code[max(m.start() - 20, 0):m.start()]):
                value += IMAGE_BASE
            if IMAGE_BASE <= value < IMAGE_BASE + SPAN:
                uses.append(Use(value, name_at(code, m.start()), path.relative_to(root).as_posix(),
                                code.count('\n', 0, m.start()) + 1))
    return uses


def compare(uses, entries):
    """(addresses used but not listed, listed addresses no code uses), both sorted, as ints."""
    used, listed = {u.address for u in uses}, {int(a, 16) for a in entries}
    return sorted(used - listed), sorted(listed - used)


def load(path=SIGNATURES):
    with open(path, encoding='utf-8') as f:
        return json.load(f)['addresses']


def main():
    uses, entries = scan(), load()
    for u in sorted(uses, key=lambda u: (u.address, u.file, u.line)):
        kind = entries.get(f'{u.address:#x}', {}).get('kind', 'MISSING')
        print(f'{u.address:#x}  {kind:<8}  {u.name:<24}  native/src/{u.file}:{u.line}')
    missing, stale = compare(uses, entries)
    print(f'{len(uses)} uses of {len({u.address for u in uses})} addresses')
    for a in missing:
        print(f'not in {SIGNATURES.name}: {a:#x}')
    for a in stale:
        print(f'in {SIGNATURES.name}, used nowhere: {a:#x}')
    return 1 if missing or stale else 0


if __name__ == '__main__':
    sys.exit(main())
