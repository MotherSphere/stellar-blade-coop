#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""ue4ss/builds/: one folder of UE4SS files per Stellar Blade build, named <TimeDateStamp>-<SizeOfImage> of the game's
executable in lower-case hex. The set of the pinned build (26123051): its README names every file; its two signature
scripts run under lua5.4 on made-up matches and on Ghidra's copy of the executable when this PC has it. No
FText_Constructor.lua anywhere under ue4ss/. NOTICE credits the scripts' sources.
Run: python3 tests/tools/ue4ss_test.py"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/port'))
import make_signatures as ms  # noqa: E402

UE4SS = ROOT / 'ue4ss'
STAMP, SIZE = ms.pinned()
SET = UE4SS / 'builds' / f'{STAMP:08x}-{SIZE:08x}'
SIGS = SET / 'UE4SS_Signatures'
EXE = Path.home() / 'Ghidra/stellar-blade/input/26123051/SB-Win64-Shipping.exe'

# Every build folder is named after the executable it serves.
builds = sorted(p.name for p in (UE4SS / 'builds').iterdir())
assert all(re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{8}', b) for b in builds), builds
assert SET.is_dir(), f'no set for the pinned build: {SET}'

# UE4SS v4.0.0 reads UE4SS_Signatures/<name>.lua only (Signatures.cpp): the fork's GUObjectArracy.lua would never
# load. FText_Constructor.lua stops some games from starting and v4.0.0 does not read it.
every = sorted(p.relative_to(UE4SS).as_posix() for p in UE4SS.rglob('*') if p.is_file())
assert not [f for f in every if f.endswith(('FText_Constructor.lua', 'GUObjectArracy.lua'))], every
assert sorted(p.name for p in SIGS.iterdir()) == ['GNatives.lua', 'GUObjectArray.lua'], list(SIGS.iterdir())

# The README has a line for each file of the set.
readme = (SET / 'README.md').read_text(encoding='utf-8')
for f in sorted(p.relative_to(SET).as_posix() for p in SET.rglob('*') if p.is_file() and p.name != 'README.md'):
    assert f'`{f}`' in readme, f'README.md has no line for {f}'

# Runs a signature script as UE4SS does: Register() gives the pattern, OnMatchFound(match) the address. Each match
# comes with the bytes from it on, which DerefToInt32 reads.
DRIVER = r'''
local window = {}
function DerefToInt32(address)
  local i = address - window.base + 1
  local b = window.bytes
  local v = b[i] | b[i + 1] << 8 | b[i + 2] << 16 | b[i + 3] << 24
  return v >= 0x80000000 and v - 0x100000000 or v
end
dofile(arg[1])
print(Register())
for k = 2, #arg, 2 do
  window.base, window.bytes = tonumber(arg[k], 16), {}
  for h in arg[k + 1]:gmatch('%x%x') do window.bytes[#window.bytes + 1] = tonumber(h, 16) end
  print(string.format('%x', OnMatchFound(window.base)))
end
'''


def run(script, matches):
    """The script's pattern and its OnMatchFound result for each (address, bytes from it on)."""
    args = [x for va, blob in matches for x in (f'{va:x}', blob.hex())]
    out = subprocess.run(['lua5.4', '-', str(script), *args], input=DRIVER, capture_output=True, text=True,
                         timeout=60)
    assert out.returncode == 0, out.stderr
    lines = out.stdout.splitlines()
    return lines[0], [int(x, 16) for x in lines[1:]]


def regex(pattern):
    """UE4SS's pattern syntax: hex bytes, ? or ?? for any byte."""
    return re.compile(b''.join(b'.' if t in ('?', '??') else re.escape(bytes([int(t, 16)])) for t in pattern.split()),
                      re.DOTALL)


def fill(pattern, disp_at, disp):
    """The pattern's bytes, wildcards 00, with a little-endian int32 at disp_at."""
    b = bytearray(0 if t in ('?', '??') else int(t, 16) for t in pattern.split())
    b[disp_at:disp_at + 4] = disp.to_bytes(4, 'little', signed=True)
    return bytes(b)


GNATIVES, GUOBJECTARRAY = SIGS / 'GNatives.lua', SIGS / 'GUObjectArray.lua'
for script in (GNATIVES, GUOBJECTARRAY):
    head = script.read_text(encoding='utf-8')
    assert 'MIT' in head and 'function Register()' in head and 'function OnMatchFound(' in head, script

# Made-up matches. GNatives: lea rax, [rip + disp32] (48 8D 05), the target is the next instruction + disp32.
# GUObjectArray: mov [rip + disp32], eax (89 05), the same rule.
pattern, _ = run(GNATIVES, [])
base = 0x140001000
_, got = run(GNATIVES, [(base, fill(pattern, 3, 0x100)), (base, fill(pattern, 3, -0x20))])
assert got == [base + 7 + 0x100, base + 7 - 0x20], [hex(g) for g in got]
pattern, _ = run(GUOBJECTARRAY, [])
_, got = run(GUOBJECTARRAY, [(base, fill(pattern, 2, 0x4250d57)), (base, fill(pattern, 2, -0x40))])
assert got == [base + 6 + 0x4250d57, base + 6 - 0x40], [hex(g) for g in got]

# Build 26123051 itself (Ghidra, 2026-11-21): GUObjectArray's pattern matches once, at 0x142b8c4e3, and gives
# 0x146ddd240. GNatives' pattern matches 83 times; every match gives 0x146f17900. Both are UE4SS.log's values.
if EXE.is_file():
    image = ms.Image(EXE.read_bytes())
    assert (image.stamp, image.size) == (STAMP, SIZE), f'{EXE} is not the executable of the pinned build'
    found = {}
    for script in (GNATIVES, GUOBJECTARRAY):
        pattern, _ = run(script, [])
        hits = [start + m.start() for _, start, blob, _ in image.sections for m in regex(pattern).finditer(blob)]
        _, got = run(script, [(va, image.at(va, 16)) for va in hits])
        found[script.name] = (hits, got)
    hits, got = found['GUObjectArray.lua']
    assert hits == [0x142b8c4e3] and got == [0x146ddd240], ([hex(h) for h in hits], [hex(g) for g in got])
    hits, got = found['GNatives.lua']
    assert len(hits) == 83 and set(got) == {0x146f17900}, (len(hits), {hex(g) for g in got})
    real = 'build 26123051: GUObjectArray 1 match, GNatives 83 matches'
else:
    real = f'build 26123051 skipped: no {EXE}'

# NOTICE credits where the files come from and keeps the MIT notice.
notice = (ROOT / 'NOTICE').read_text(encoding='utf-8')
for word in ('https://github.com/Rev-OG-UwU/SB-UE4SS', 'a63c3f8ecfc51c679082c30805d8af5c3514ba9a',
             'https://github.com/Chrisr0/RE-UE4SS', 'e6e59de93656ed3caf242233a0b6f63e073ba3df',
             'Copyright (c) 2022 Narknon', 'Permission is hereby granted, free of charge', 'backup_saves()',
             'FText_Constructor.lua'):
    assert word in notice, f'NOTICE lacks {word}'

print(f'ue4ss_test: ok ({len(builds)} build set; {real})')
