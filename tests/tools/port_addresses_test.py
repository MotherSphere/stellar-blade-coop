#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/port/addresses.py on a fake source file in a temporary directory, then on native/src: every game address the
native code uses has an entry in tools/port/signatures.json. Every entry is used.
Run: python3 tests/tools/port_addresses_test.py"""
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/port'))
import addresses  # noqa: E402

FAKE = r'''// kOld = 0x141000000 in a comment
/* 0x141000010
   0x141000020 */
const char *kText = "0x141000030 \" 0x141000031", *kRaw = R"x(0x141000040 ")" )x";
constexpr Pair kQ = {'"', 0x1410000c0, "y"};
constexpr uint64_t kA = 0x141000050, kSmall = 0x10, kB = 0x1'4100'0060;
constexpr uint32_t kPinRva = 0x2bfd488, kSize = 0x2bfd488;
constexpr uint64_t kTable[2] = {0x141000070,
                                0x141000080};
constexpr Kind kKinds[2] = {{"a, b", 0x56, f(1, 2), 0x141000090}, {"c", 0x57, 0, 0x1410000a0}};
bool same(uint64_t v) { return v == 0x1410000B0; }
'''

with tempfile.TemporaryDirectory() as tmp:
    (Path(tmp) / 'part').mkdir()
    (Path(tmp) / 'part/fake.h').write_text(FAKE)
    (Path(tmp) / 'part/notes.txt').write_text('constexpr uint64_t kNot = 0x141000100;')
    got = [tuple(u) for u in addresses.scan(tmp)]
want = [(0x1410000c0, 'kQ[1]', 'part/fake.h', 5), (0x141000050, 'kA', 'part/fake.h', 6),
        (0x141000060, 'kB', 'part/fake.h', 6), (0x142bfd488, 'kPinRva', 'part/fake.h', 7),
        (0x141000070, 'kTable[0]', 'part/fake.h', 8), (0x141000080, 'kTable[1]', 'part/fake.h', 9),
        (0x141000090, 'kKinds[0][3]', 'part/fake.h', 10), (0x1410000a0, 'kKinds[1][3]', 'part/fake.h', 10),
        (0x1410000b0, '?', 'part/fake.h', 11)]
assert got == want, f'scan of the fake file:\n{got}\nwant\n{want}'

uses = [addresses.Use(0x141000050, 'kA', 'part/fake.h', 6)]
assert addresses.compare(uses, {'0x141000050': {}, '0x141000060': {}}) == ([], [0x141000060])
assert addresses.compare(uses, {}) == ([0x141000050], [])

uses, entries = addresses.scan(), addresses.load()
missing, stale = addresses.compare(uses, entries)
assert not missing, ('native/src uses addresses that tools/port/signatures.json lacks (check each in Ghidra, then add'
                     ' it): ' + ', '.join(f'{a:#x}' for a in missing))
assert not stale, 'tools/port/signatures.json lists addresses no code uses: ' + ', '.join(f'{a:#x}' for a in stale)
kinds = {'function', 'code', 'rdata', 'global', 'section', 'image'}
for address, entry in entries.items():
    assert address == f'{int(address, 16):#x}', f'{address}: write it as lower-case hex with 0x'
    assert entry.get('kind') in kinds, f'{address}: kind {entry.get("kind")!r} is not one of {sorted(kinds)}'
    assert entry.get('ghidra'), f'{address}: no ghidra text'
print(f'port_addresses_test: ok ({len(uses)} uses of {len(entries)} addresses)')
