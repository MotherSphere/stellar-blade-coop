#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/port/make_signatures.py: its instruction decoder on hand-written instructions, every kind of signature on a
small PE file built here, its main writing signatures.json and ue4ss.json in one pass, then the form of each entry in
tools/port/signatures.json and tools/port/ue4ss.json. tools/port/find.py on that file and on copies of it with moved
code, a pattern that matches three times, a holder held twice, a missing function and a value read outside the file.
Its UE4SS signature scripts run under lua5.4 and give their address; a signature UE4SS cannot use gives none. Then
find.py on the executable of build 26123051 when this PC has Ghidra's copy of it: every entry is found at its own
address and each UE4SS target's script gives it.
Run: python3 tests/tools/port_signatures_test.py"""
import contextlib
import io
import json
import re
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/port'))
import addresses  # noqa: E402
import find  # noqa: E402
import make_signatures as ms  # noqa: E402

# (instruction, length, offset of its rel32 or RIP-relative disp32), checked against capstone 5.0 when written.
CASES = [
    ('90', 1, None), ('c3', 1, None), ('e8 00 00 00 00', 5, 1), ('e9 00 00 00 00', 5, 1), ('e4 60', 2, None),
    ('0f 84 00 00 00 00', 6, 2), ('48 8b 05 00 00 00 00', 7, 3), ('48 8d 0d 00 00 00 00', 7, 3),
    ('80 3d 00 00 00 00 01', 7, 2), ('c7 05 00 00 00 00 01 00 00 00', 10, 2), ('66 c7 05 00 00 00 00 01 00', 9, 3),
    ('48 89 5c 24 08', 5, None), ('48 81 ec b0 00 00 00', 7, None), ('48 8b 84 24 a0 00 00 00', 8, None),
    ('8b 04 25 00 10 00 00', 7, None), ('48 b8 88 77 66 55 44 33 22 11', 10, None), ('b8 01 00 00 00', 5, None),
    ('66 b8 01 00', 4, None), ('f6 c1 01', 3, None), ('f7 c1 01 00 00 00', 6, None), ('f7 d8', 2, None),
    ('0f 1f 84 00 00 00 00 00', 8, None), ('f3 0f 10 05 00 00 00 00', 8, 4), ('66 0f 3a 0f c1 08', 6, None),
    ('66 0f 38 00 05 00 00 00 00', 9, 5), ('c5 f8 77', 3, None), ('c5 fa 10 05 00 00 00 00', 8, 4),
    ('c4 e3 79 16 c0 01', 6, None), ('62 f1 7c 48 10 05 00 00 00 00', 10, 6), ('a1 88 77 66 55 44 33 22 11', 9, None),
    ('ff 15 00 00 00 00', 6, 2), ('ff 25 00 00 00 00', 6, 2), ('c2 08 00', 3, None), ('41 0f b6 05 00 00 00 00', 8, 4),
    ('0f ba e0 03', 4, None), ('66 0f 70 c1 1b', 5, None), ('69 c0 10 00 00 00', 6, None), ('6b c0 10', 3, None),
]
# (short jump, length, offset of its rel8): jmp, jcc, loop, jrcxz, a jcc with a branch hint.
SHORT = [('eb 05', 2, 1), ('74 a2', 2, 1), ('7f 00', 2, 1), ('e0 fe', 2, 1), ('e3 10', 2, 1), ('2e 75 07', 3, 2)]
for text, length, rel, short in [(*c, None) for c in CASES] + [(t, n, None, s) for t, n, s in SHORT]:
    got = ms.decode(bytes.fromhex(text) + bytes(16), 0)
    assert got == (length, rel, short), f'decode({text}) gave {got}, want {(length, rel, short)}'
try:
    ms.decode(b'\x06' + bytes(16), 0)
    raise AssertionError('decode took 06, which 64-bit code does not use')
except ValueError:
    pass

BASE, TEXT, RDATA, DATA = 0x140000000, 0x1000, 0x2000, 0x3000
# The fake game's functions: bytes, or (target, n) for a rel32 whose instruction ends n bytes after it.
FUNCS = {
    'unique': [b'\x48\x89\x5c\x24\x08\xb8\x11\x22\x33\x44\xc3'],  # mov [rsp+8], rbx; mov eax, 0x44332211; ret
    'copy_a': [b'\x48\x8b\x05', ('table_a', 0), b'\x48\x83\xc0\x01\xc3'],  # mov rax, [table_a]; add rax, 1; ret
    'copy_b': [b'\x48\x8b\x05', ('table_b', 0), b'\x48\x83\xc0\x01\xc3'],  # the same with table_b
    'caller_a': [b'\xe8', ('copy_a', 0), b'\xb9\x01\x00\x00\x00\x0f\xaf\xc1\xc3'],  # call; mov ecx, 1; imul; ret
    'caller_b': [b'\xe8', ('copy_b', 0), b'\xb9\x02\x00\x00\x00\x0f\xaf\xc1\xc3'],
    'maker': [b'\x48\x8d\x0d', ('vtable', 0), b'\x48\x89\x0b\x33\xc0\xc3'],  # lea rcx, [vtable]; mov [rbx], rcx
    'check': [b'\x80\x3d', ('flag', 1), b'\x01\x0f\x94\xc0\xc3'],  # cmp byte [flag], 1; sete al; ret
    'zero_a': [b'\x31\xc0\xc3'],  # xor eax, eax; ret: too short for a signature of its own
    'zero_b': [b'\x31\xc0\xc3'],
    'lone': [b'\x48\x89\x74\x24\x10\xb8\x55\x66\x77\x88\xc3'],  # only a vtable no code loads points here
    # mov ecx, 7, then copy_a's body on counter: the load's own run occurs three times.
    'pre': [b'\xb9\x07\x00\x00\x00\x48\x8b\x05', ('counter', 0), b'\x48\x83\xc0\x01\xc3'],
    # mov rax, imm64 whose bytes read "call table_a; nop x3"; mov eax, 0xefbeadde; ret
    'decoy': [b'\x48\xb8\xe8', ('table_a', 0), b'\x90\x90\x90\xb8\xde\xad\xbe\xef\xc3'],
    # mov [rsp+0x18], rdi; jmp out of .text; then junk that differs between the two stubs
    'stub_a': [b'\x48\x89\x7c\x24\x18\xe9', ('outside', 0), b'\xb8\x99\x99\x99\x99\xc3'],
    'stub_b': [b'\x48\x89\x7c\x24\x18\xe9', ('outside', 0), b'\xb8\x98\x98\x98\x98\xc3'],
}
SYMBOLS = {'table_a': BASE + DATA, 'table_b': BASE + DATA + 8, 'flag': BASE + DATA + 0x10, 'counter': BASE + DATA + 0x18,
           'vtable': BASE + RDATA + 0x100, 'vtable2': BASE + RDATA + 0x148, 'outside': BASE + 0x8000}


def fake_exe(funcs, stamp=0x11223344):
    """A PE32+ file with the functions in .text (16-byte aligned, int3 between them), their .pdata runs and the two
    vtables in .rdata, the tables and the flag in .data. Returns (file bytes, {name: address})."""
    at, size = dict(SYMBOLS), 0
    for name, parts in funcs.items():
        at[name] = BASE + TEXT + size
        size += sum(len(p) if isinstance(p, bytes) else 4 for p in parts)
        size += -size % 16
    text, pdata = bytearray(b'\xcc' * size), b''
    for name, parts in funcs.items():
        pos = start = at[name] - BASE - TEXT
        for p in parts:
            if not isinstance(p, bytes):
                p = struct.pack('<i', at[p[0]] - (BASE + TEXT + pos + 4 + p[1]))
            text[pos:pos + len(p)] = p
            pos += len(p)
        pdata += struct.pack('<III', TEXT + start, TEXT + pos, 0)
    rdata = bytearray(0x200)
    rdata[:len(pdata)] = pdata
    struct.pack_into('<4Q', rdata, 0x100, at['unique'], at['zero_a'], at['maker'], at['zero_b'])
    struct.pack_into('<2Q', rdata, 0x148, at['unique'], at['lone'])  # 0x120 to 0x147 hold no code: another vtable.
    sections = [(b'.text', TEXT, bytes(text), 0x60000020), (b'.rdata', RDATA, bytes(rdata), 0x40000040),
                (b'.data', DATA, bytes(0x20), 0xc0000040)]
    head = bytearray(0x400)
    head[:2], head[0x40:0x44] = b'MZ', b'PE\0\0'
    struct.pack_into('<I', head, 0x3c, 0x40)
    struct.pack_into('<HHIIIHH', head, 0x44, 0x8664, len(sections), stamp, 0, 0, 240, 0x22)
    struct.pack_into('<H', head, 0x58, 0x20b)
    struct.pack_into('<Q', head, 0x58 + 24, BASE)
    struct.pack_into('<I', head, 0x58 + 56, 0x4000)
    struct.pack_into('<II', head, 0x58 + 112 + 3 * 8, RDATA, len(pdata))
    body = b''
    for k, (name, rva, blob, flags) in enumerate(sections):
        struct.pack_into('<8sIIII12xI', head, 0x58 + 240 + 40 * k, name, len(blob), rva, len(blob), 0x400 + len(body),
                         flags)
        body += blob
    return bytes(head) + body, at


data, at = fake_exe(FUNCS)
image = ms.Image(data)
entries = {f'{a:#x}': {'kind': kind} for a, kind in [
    (at['unique'], 'function'), (at['unique'] + 5, 'code'), (at['copy_b'], 'function'), (at['zero_a'], 'function'),
    (at['table_a'], 'global'), (at['flag'], 'global'), (at['counter'], 'global'), (at['vtable'] + 0x10, 'rdata'),
    (at['vtable2'], 'rdata'), (BASE, 'image')]}
out, failed = ms.build(image, entries)
assert not failed, failed


def ref(frm, disp, end, add=0, **more):
    return {'from': f'{at[frm]:#x}', 'disp': disp, 'end': end, 'add': add, **more}


want = {
    at['unique']: ('48 89 5c 24 08 b8 11 22 33 44', None),  # its own run
    at['unique'] + 5: ('b8 11 22 33 44 c3', None),
    at['copy_b']: ('e8 ?? ?? ?? ?? b9 02 00 00 00', {'ref': ref('caller_b', 1, 5)}),  # copy_a has the same bytes
    at['zero_a']: ('48 8d 0d ?? ?? ?? ?? 48 89 0b', {'ref': ref('maker', 3, 7, 8, read=True)}),  # read in vtable + 8
    # decoy's imm64 reads as a call to table_a from its third byte: not an instruction, so not a reference.
    at['table_a']: ('e8 ?? ?? ?? ?? b9 01 00 00 00', {'ref': ref('caller_a', 1, 5, then=ref('copy_a', 3, 7))}),
    at['flag']: ('80 3d ?? ?? ?? ?? 01 0f 94 c0', {'ref': ref('check', 2, 7)}),  # an imm8 after the field
    # The load's own run is also copy_a's and copy_b's: the run starts at the mov before it.
    at['counter']: ('b9 07 00 00 00 48 8b 05 ?? ?? ?? ??',
                    {'ref': {'from': f'{at["pre"] + 5:#x}', 'disp': 8, 'end': 12, 'add': 0}}),
    at['vtable'] + 0x10: ('48 8d 0d ?? ?? ?? ?? 48 89 0b', {'ref': ref('maker', 3, 7, 0x10)}),
    at['vtable2']: ('48 89 74 24 10 b8 55 66 77 88', {'holder': {'add': -8}}),  # unique is held twice
}
for address, (pattern, extra) in want.items():
    e = out[f'{address:#x}']
    got = {k: v for k, v in e.items() if k in ('ref', 'holder')} or None
    assert (e.get('pattern'), got) == (pattern, extra), f'{address:#x}: {e}\nwant {pattern} {extra}'
    assert e['mask'] == ''.join('?' if t == '??' else 'x' for t in pattern.split()), e
    assert ms.resolve(image, e) == address, e
assert 'pattern' not in out[f'{BASE:#x}'], 'the image base got a signature'

# A second copy of unique's bytes: its signature matches twice and gives nothing.
twice, _ = fake_exe({**FUNCS, 'again': FUNCS['unique']})
assert ms.resolve(ms.Image(twice), out[f'{at["unique"]:#x}']) is None, 'a signature that matches twice gave an address'

# A second place in .rdata that holds lone: the holder is no longer one place and gives nothing.
held = bytearray(data)
k = data.index(struct.pack('<2Q', at['unique'], at['lone']))  # vtable2, at .rdata + 0x148
held[k + 0x58:k + 0x60] = struct.pack('<Q', at['lone'])  # .rdata + 0x1a0, free
assert ms.resolve(ms.Image(bytes(held)), out[f'{at["vtable2"]:#x}']) is None, 'a holder held twice gave an address'

# lone's address at .rdata + 0x1a4, which is not 8-byte aligned: not a place, so the holder still gives vtable2.
odd = bytearray(data)
odd[k + 0x5c:k + 0x64] = struct.pack('<Q', at['lone'])
assert ms.resolve(ms.Image(bytes(odd)), out[f'{at["vtable2"]:#x}']) == at['vtable2'], 'an unaligned copy counted'

# Two runs that differ first in a short jump's rel8, then in an immediate: the rel8 is a wildcard, so the run goes on.
short = bytes.fromhex('48 89 5c 24 08 74 07 b8 01 00 00 00 c3 cc 48 89 5c 24 08 74 04 b8 02 00 00 00 c3')
assert ms.shortest(short, 0) == (short[:12], 'xxxxxx?xxxxx'), f'a rel8 told two runs apart: {ms.shortest(short, 0)}'

# The two stubs differ only after their jump out of .text: a run stops at that jump, so neither gets one.
assert ms.shortest(image.code, at['stub_a'] - image.code_va) is None, 'a run went on past a jump out of .text'

# Any other executable than the pinned build is refused before signatures.json is read: one whose TimeDateStamp and
# SizeOfImage both differ, then one with only the stamp different, then one with only SizeOfImage different.
stamp, size = ms.pinned()
for exe_stamp, exe_size in ((0x11223344, 0x4000), (0x11223344, size), (stamp, 0x4000)):
    other = bytearray(fake_exe(FUNCS, exe_stamp)[0])
    struct.pack_into('<I', other, 0x58 + 56, exe_size)  # SizeOfImage in the PE header.
    with tempfile.TemporaryDirectory() as tmp, mock.patch.object(addresses, 'SIGNATURES', Path(tmp) / 'none.json'):
        exe = Path(tmp) / 'SB-Win64-Shipping.exe'
        exe.write_bytes(other)
        try:
            ms.main(['make_signatures.py', str(exe)])
            raise AssertionError(f'main took stamp {exe_stamp:#x}, size {exe_size:#x}: not the pinned build')
        except SystemExit as e:
            assert 'not the pinned build' in str(e.code), e.code

# main on the fake executable as the pinned build: one build for both files. signatures.json takes the code's names,
# ue4ss.json keeps its own. flag is in both and gets the same signature in each. Old signature fields go.
with tempfile.TemporaryDirectory() as tmp:
    exe, sig_file, ue4ss_file = Path(tmp) / 'SB-Win64-Shipping.exe', Path(tmp) / 'sig.json', Path(tmp) / 'ue4ss.json'
    exe.write_bytes(data)
    flag, unique, table = (f'{at[k]:#x}' for k in ('flag', 'unique', 'table_a'))
    sig_file.write_text(json.dumps({'build': 'old', 'addresses': {
        flag: {'kind': 'global', 'ghidra': 'flag'},
        unique: {'kind': 'function', 'ghidra': 'unique', 'name': 'kOld', 'pattern': '90', 'mask': 'x'}}}))
    ue4ss_file.write_text(json.dumps({'build': 'old', 'addresses': {
        flag: {'kind': 'global', 'ghidra': 'flag, a UE4SS target', 'name': 'Flag'},
        table: {'kind': 'global', 'ghidra': 'table_a', 'name': 'Table', 'pattern': '90', 'mask': 'x', 'holder': {}}}}))
    uses = [addresses.Use(at['flag'], 'kFlag', 'a.h', 1), addresses.Use(at['unique'], 'kUnique', 'a.h', 2)]
    with mock.patch.object(addresses, 'SIGNATURES', sig_file), mock.patch.object(addresses, 'UE4SS', ue4ss_file), \
            mock.patch.object(addresses, 'scan', lambda: uses), \
            mock.patch.object(ms, 'pinned', lambda: (0x11223344, 0x4000)), contextlib.redirect_stdout(io.StringIO()):
        assert ms.main(['make_signatures.py', str(exe)]) == 0
    sig_doc, ue4ss_doc = json.loads(sig_file.read_text()), json.loads(ue4ss_file.read_text())


def signature(e):
    return {k: v for k, v in e.items() if k in ('pattern', 'mask', 'ref', 'holder')}


assert sig_doc['build'] == ue4ss_doc['build'] == 'old', (sig_doc['build'], ue4ss_doc['build'])
assert sig_doc['addresses'] == {flag: {'kind': 'global', 'ghidra': 'flag', 'name': 'kFlag', **signature(out[flag])},
                                unique: {'kind': 'function', 'ghidra': 'unique', 'name': 'kUnique',
                                         **signature(out[unique])}}, sig_doc
assert ue4ss_doc['addresses'] == {
    flag: {'kind': 'global', 'ghidra': 'flag, a UE4SS target', 'name': 'Flag', **signature(out[flag])},
    table: {'kind': 'global', 'ghidra': 'table_a', 'name': 'Table', **signature(out[table])}}, ue4ss_doc

# Every entry of signatures.json that a port must find has a signature in the form the tool writes. So has every
# UE4SS target in ue4ss.json: the three files that UE4SS_Signatures/ can hold for Stellar Blade.
names = {}
for u in addresses.scan():
    names.setdefault(f'{u.address:#x}', set()).add(u.name)
for address, e in addresses.load().items():
    assert e.get('name') == ', '.join(sorted(names.get(address, ()))), (
        f'{address}: name {e.get("name")!r}; the code names it {sorted(names.get(address, ()))}')
TARGETS = addresses.load(addresses.UE4SS)
assert sorted(e['name'] for e in TARGETS.values()) == ['FText_Constructor', 'GNatives', 'GUObjectArray'], TARGETS
for address, e in TARGETS.items():
    assert address == f'{int(address, 16):#x}' and e['kind'] in ms.SIGNED and e.get('ghidra'), (address, e)
for address, e in [*addresses.load().items(), *TARGETS.items()]:
    if e['kind'] not in ms.SIGNED:
        assert 'pattern' not in e, f'{address}: a {e["kind"]} entry comes from the PE header, not a signature'
        continue
    assert e.get('pattern') and e.get('mask'), (f'{address}: no signature; run python3 tools/port/make_signatures.py'
                                                ' on the executable of build 26123051')
    tokens = e['pattern'].split()
    assert len(tokens) == len(e['mask']) <= ms.MAX_LEN, f'{address}: pattern and mask lengths'
    assert all((t == '??') == (m == '?') and (t == '??' or len(t) == 2) for t, m in zip(tokens, e['mask'])), address
    assert e['mask'][0] == 'x' and e['mask'].count('x') >= ms.MIN_FIXED, f'{address}: too few bytes to match'
    r = e.get('ref')
    while r:
        assert 0 < r['disp'] and r['disp'] + 4 <= r['end'], f'{address}: ref {r}'
        assert int(r['from'], 16) and isinstance(r['add'], int), f'{address}: ref {r}'
        r = r.get('then')
    assert 'ref' not in e or 'holder' not in e, f'{address}: both a ref and a holder'


def report(exe, entries):
    """({address: state}, the count line, the exit code) of find.py's report on the executable exe."""
    printed = io.StringIO()
    with contextlib.redirect_stdout(printed):
        code = find.report(ms.Image(exe), entries)
    lines = printed.getvalue().splitlines()
    return {line.split()[0]: line.rsplit('  ', 1)[1] for line in lines[:-1]}, lines[-1], code


# find.py on the fake executable: every entry is found at its address, the image base and a section included.
found = {**out, f'{BASE + RDATA:#x}': {'kind': 'section', 'ghidra': 'start of .rdata, end of .text'}}
states, count, code = report(data, found)
assert states == {a: f'found {a}' for a in found}, states
assert (count, code) == (f'{len(found)} found (0 moved), 0 ambiguous, 0 missing', 0), (count, code)
assert find.locate(image, {'kind': 'section', 'ghidra': 'start of .bss, end of .data'}) == [], 'a missing section'
rebased = bytearray(data)
struct.pack_into('<Q', rebased, 0x58 + 24, 0x180000000)  # The image base in the PE header.
assert find.locate(ms.Image(bytes(rebased)), {'kind': 'image'}) == [0x180000000], 'the image base is not the header\'s'

# A function before the others moves all code by 16 bytes: the code addresses move, the data addresses stay.
moved, at2 = fake_exe({'pad': [b'\x55\x5d\xc3'], **FUNCS})  # push rbp; pop rbp; ret
assert at2['unique'] == at['unique'] + 16 and at2['table_a'] == at['table_a']
states, count, code = report(moved, found)
shift = {at['unique']: 16, at['unique'] + 5: 16, at['copy_b']: 16, at['zero_a']: 16}
assert states == {a: f'found {int(a, 16) + shift.get(int(a, 16), 0):#x}' for a in found}, states
assert (count, code) == (f'{len(found)} found (4 moved), 0 ambiguous, 0 missing', 0), (count, code)

# unique's bytes three times: its two signatures match three times. lone held twice: the holder's code is in two places.
states, count, code = report(fake_exe({**FUNCS, 'again': FUNCS['unique'], 'again2': FUNCS['unique']})[0], found)
assert states[f'{at["unique"]:#x}'] == states[f'{at["unique"] + 5:#x}'] == 'ambiguous (3 matches)', states
assert (count, code) == (f'{len(found) - 2} found (0 moved), 2 ambiguous, 0 missing', 1), (count, code)
states, count, code = report(bytes(held), found)
assert states[f'{at["vtable2"]:#x}'] == 'ambiguous (2 matches)', states
assert (count, code) == (f'{len(found) - 1} found (0 moved), 1 ambiguous, 0 missing', 1), (count, code)

# Without check, nothing loads flag: its entry is missing. zero_a, right after check, moves 16 bytes down.
states, count, code = report(fake_exe({k: v for k, v in FUNCS.items() if k != 'check'})[0], found)
assert states[f'{at["flag"]:#x}'] == 'missing' and states[f'{at["zero_a"]:#x}'] == f'found {at["zero_a"] - 16:#x}'
assert (count, code) == (f'{len(found) - 1} found (1 moved), 0 ambiguous, 1 missing', 1), (count, code)

# zero_a's ref reads its address 1 MB past vtable + 8, outside the file: missing.
far = {a: dict(e, ref={**e['ref'], 'add': 0x100000}) if a == f'{at["zero_a"]:#x}' else e for a, e in found.items()}
states, count, code = report(data, far)
assert states[f'{at["zero_a"]:#x}'] == 'missing', states
assert (count, code) == (f'{len(found) - 1} found (0 moved), 0 ambiguous, 1 missing', 1), (count, code)

# A UE4SS signature script under lua5.4 as UE4SS runs it: Register() gives the pattern, OnMatchFound(match) the
# address. DerefToInt32 reads the bytes given and, as UE4SS's, gives nil for a value of 0.
DRIVER = r'''
local mem = {}
for k = 3, #arg, 2 do
  local base, i = tonumber(arg[k], 16), 0
  for h in arg[k + 1]:gmatch('%x%x') do mem[base + i] = tonumber(h, 16); i = i + 1 end
end
function DerefToInt32(a)
  local v = mem[a] | mem[a + 1] << 8 | mem[a + 2] << 16 | mem[a + 3] << 24
  if v == 0 then return nil end
  return v >= 0x80000000 and v - 0x100000000 or v
end
dofile(arg[1])
print(Register())
if arg[2] then print(string.format('%x', OnMatchFound(tonumber(arg[2], 16)))) end
'''


def lua(text, img, entry):
    """The addresses the script text gives in img, one per place its pattern matches in any section, as UE4SS scans
    the whole image. Each run gets the bytes from the match on and from each copy start a ref with then reaches."""
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / 'script.lua'
        path.write_text(text)

        def run(*args):
            done = subprocess.run(['lua5.4', '-', str(path), *args], input=DRIVER, capture_output=True, text=True,
                                  timeout=60)
            assert done.returncode == 0, done.stderr
            return done.stdout.split('\n')

        pattern = run()[0]
        rx = re.compile(b''.join(b'.' if t == '??' else re.escape(bytes([int(t, 16)])) for t in pattern.split()), re.S)
        got = []
        for va in [start + m.start() for _, start, blob, _ in img.sections for m in rx.finditer(blob)]:
            windows, step, ref = [(va, img.at(va, ms.MAX_LEN))], va, entry.get('ref')
            while ref and ref.get('then'):
                step += ref['end'] + struct.unpack('<i', img.at(step + ref['disp'], 4))[0] + ref['add']
                windows.append((step, img.at(step, ms.MAX_LEN)))
                ref = ref['then']
            got.append(int(run(f'{va:x}', *(x for w, b in windows for x in (f'{w:x}', b.hex())))[1], 16))
        return pattern, got


# Scripts from the fake signatures: a function's own run, a ref, a ref with an add, a ref with then. Each pattern
# matches once in the whole image and the script gives the address. In the build with moved code, the moved address.
for name, symbol, add in (('Unique', 'unique', 0), ('Flag', 'flag', 0), ('Slot', 'vtable', 0x10),
                          ('Table', 'table_a', 0)):
    entry = dict(out[f'{at[symbol] + add:#x}'], name=name)
    text = find.script(image, entry)
    assert text and text.startswith('-- Copyright (C) 2026 MotherSphere') and f'UE4SS_Signatures/{name}.lua' in text
    assert lua(text, image, entry) == (entry['pattern'], [at[symbol] + add]), (name, lua(text, image, entry))
    assert lua(find.script(ms.Image(moved), entry), ms.Image(moved), entry)[1] == [at2[symbol] + add], name
# A holder and a read of 8 bytes need more than DerefToInt32: no script. Neither for a signature found twice or not
# at all, nor for one that also matches in .rdata, where UE4SS scans too though find.py looks in the code only.
copied = bytearray(data)
vt2 = data.index(struct.pack('<2Q', at['unique'], at['lone']))  # vtable2, at .rdata + 0x148
copied[vt2 + 0x60:vt2 + 0x6a] =bytes.fromhex(out[f'{at["unique"]:#x}']['pattern'])  # .rdata + 0x1a8, free
assert find.locate(ms.Image(bytes(copied)), out[f'{at["unique"]:#x}']) == [at['unique']]
# unique's last immediate byte changed in the code, its old bytes in .rdata: the pattern matches once, outside the code.
elsewhere = bytearray(fake_exe({**FUNCS, 'unique': [FUNCS['unique'][0][:9] + b'\x45\xc3']})[0])
elsewhere[vt2 + 0x60:vt2 + 0x6a] = copied[vt2 + 0x60:vt2 + 0x6a]
assert find.locate(ms.Image(bytes(elsewhere)), out[f'{at["unique"]:#x}']) == []
for img, address in ((image, at['vtable2']), (image, at['zero_a']), (ms.Image(bytes(copied)), at['unique']),
                     (ms.Image(bytes(elsewhere)), at['unique']),
                     (ms.Image(fake_exe({**FUNCS, 'again': FUNCS['unique']})[0]), at['unique']),
                     (ms.Image(fake_exe({k: v for k, v in FUNCS.items() if k != 'check'})[0]), at['flag'])):
    assert find.script(img, dict(out[f'{address:#x}'], name='None')) is None, hex(address)


def ue4ss(img, targets):
    """(printed text, exit code) of find.py's UE4SS part."""
    printed = io.StringIO()
    with contextlib.redirect_stdout(printed):
        code = find.ue4ss(img, targets)
    return printed.getvalue(), code


# find.py's UE4SS part: the report of the targets, then a script for each, or a line that says it has none.
both = {f'{a:#x}': dict(out[f'{a:#x}'], name=n) for n, a in (('Flag', at['flag']), ('Held', at['vtable2']))}
text, code = ue4ss(image, both)
assert text.startswith('UE4SS signature targets (ue4ss.json):\n'), text
assert '2 found (0 moved), 0 ambiguous, 0 missing\n' in text and code == 1, (text, code)
assert text.count('function Register()') == 1 and '-- UE4SS_Signatures/Flag.lua:' in text, text
assert '\nUE4SS_Signatures/Held.lua: no script. ' in text, text
text, code = ue4ss(image, {f'{at["flag"]:#x}': both[f'{at["flag"]:#x}']})
assert code == 0 and find.script(image, both[f'{at["flag"]:#x}']) in text, (text, code)

# The executable of build 26123051 itself: every entry of signatures.json and ue4ss.json is found at its own address.
# Each UE4SS target's script matches once in the whole image and gives it. Ghidra, 2026-11-21: FUN_142862fc0 builds
# an FText from an FString&& (0x70-byte text history, FText 0x18 bytes); FUN_142b79420 calls (&DAT_146f17900)[opcode]
# until opcode 4 (GNatives); FUN_142b8bc20 writes DAT_146ddd240 and the fields after it (GUObjectArray).
EXE = Path.home() / 'Ghidra/stellar-blade/input/26123051/SB-Win64-Shipping.exe'
assert {e['name']: a for a, e in TARGETS.items()} == {
    'FText_Constructor': '0x142862fc0', 'GNatives': '0x146f17900', 'GUObjectArray': '0x146ddd240'}, TARGETS
if EXE.is_file():
    real = EXE.read_bytes()
    assert ms.Image(real).stamp == ms.pinned()[0], f'{EXE} is not the executable of build 26123051'
    entries = addresses.load()
    states, count, code = report(real, entries)
    assert states == {a: f'found {a}' for a in entries}, [(a, s) for a, s in states.items() if s != f'found {a}']
    assert code == 0, count
    real_image = ms.Image(real)
    text, code = ue4ss(real_image, TARGETS)
    assert code == 0, text
    for a, e in TARGETS.items():
        assert lua(find.script(real_image, e), real_image, e) == (e['pattern'], [int(a, 16)]), (e['name'], text)
    real = f'find.py on build 26123051: {count}; 3 UE4SS scripts'
else:
    real = f'find.py on build 26123051 skipped: no {EXE}'
print(f'port_signatures_test: ok ({len(CASES) + len(SHORT)} instructions, {len(want)} fake signatures; {real})')
