#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Byte signatures for the addresses in tools/port/signatures.json and tools/port/ue4ss.json, read from the executable
of the pinned build.

A signature is a run of whole instructions in the code section (the image's first section) that occurs there exactly
once. The 4-byte field of a relative call or jump (rel32) and of a RIP-relative operand is a wildcard: it changes as
soon as code or data moves. The 1-byte field of a short jump (rel8) is one too: it changes when the code between the
jump and its target changes length. For each function, code, global and rdata address the tool tries in this order:
- for a function or code address, the shortest run from the address, up to 128 bytes;
- an instruction whose field gives the address: a call, a jump or a RIP-relative load ("ref"). The run may start up
  to 48 bytes before it. For a data address that no instruction gives, one that gives the nearest address below it
  (a vtable's start for one of its slots) with "add" the distance. For a function that only a vtable points to, one
  that gives that slot, with "read": the function is the 8 bytes stored there;
- for a vtable slot, the run of the code that the slot or a neighbour slot holds, when no other place holds that
  code's address ("holder");
- for an instruction inside identical copies of a function (a template), a call to its copy ("ref" with "then").
The image and section entries come from the PE header. They get no signature. docs/dev/porting.md says how each kind
of signature gives its address back. The tool checks that every signature matches once and gives its address back.
It refuses an executable whose TimeDateStamp or SizeOfImage differ from check_build()'s.

Run: python3 tools/port/make_signatures.py <SB-Win64-Shipping.exe> (rewrites signatures.json and ue4ss.json; exit 1 on
a failure)"""
import bisect
import json
import re
import struct
import sys
from collections import namedtuple
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # python3 -I leaves the script's folder out.
import addresses  # noqa: E402

ENGINE = addresses.ROOT / 'native/src/game/partner/engine.h'
MAX_LEN = 128  # Bytes a signature may span.
MIN_FIXED = 6  # Bytes that must match in the shortest signature tried.
MAX_REFS = 16  # Referencing instructions tried per address, spread over them all.
BACK = 48  # How far before a referencing instruction a signature may start.
WINDOW = 0x2000  # How far below a data address the nearest referenced one may be (a vtable of 1024 slots).
SIGNED = ('function', 'code', 'global', 'rdata')


def _set(spec):
    """The bytes of a list of hex values and ranges: '00-03 63' is {0, 1, 2, 3, 0x63}."""
    out = set()
    for part in spec.split():
        lo, _, hi = part.partition('-')
        out.update(range(int(lo, 16), int(hi or lo, 16) + 1))
    return frozenset(out)


PREFIXES = _set('26 2e 36 3e 64-67 f0 f2-f3')
INVALID1 = _set('06-07 0e 16-17 1e-1f 27 2f 37 3f 60-61 82 9a ce d4-d6 ea')
MODRM1 = _set('00-03 08-0b 10-13 18-1b 20-23 28-2b 30-33 38-3b 63 69 6b 80-8f c0-c1 c6-c7 d0-d3 d8-df f6-f7 fe-ff')
IMM8_1 = _set('04 0c 14 1c 24 2c 34 3c 6a 6b 70-7f 80 83 a8 b0-b7 c0-c1 c6 cd e0-e7 eb')
IMMZ_1 = _set('05 0d 15 1d 25 2d 35 3d 68 69 81 a9 c7')
NO_MODRM2 = _set('05-09 0b 0e 30-35 37 77 a0-a2 a8-aa c8-cf')
INVALID2 = _set('04 0a 0c 0f 24-27 36 39 3b-3f 7a-7b a6-a7 ff')
IMM8_2 = _set('70-73 a4 ac ba c2 c4-c6')


def _modrm(code, i):
    """(bytes of the ModRM at code[i] with its SIB and displacement, position of its RIP-relative disp32 or None)."""
    mod, rm = code[i] >> 6, code[i] & 7
    if mod == 3:
        return 1, None
    if mod == 0 and rm == 5:
        return 5, i + 1
    if rm == 4 and mod == 0 and code[i + 1] & 7 == 5:
        return 6, None
    return (2 if rm == 4 else 1) + (0, 1, 4)[mod], None


def decode(code, i):
    """(length, position of a rel32 or RIP-relative disp32 or None, position of a rel8 or None) of the x86-64
    instruction at code[i]. Raises ValueError on an opcode that 64-bit code does not use."""
    s, opsize, addr32, rexw = i, False, False, False
    while code[i] in PREFIXES or code[i] & 0xf0 == 0x40:  # Only a REX right before the opcode counts.
        opsize |= code[i] == 0x66
        addr32 |= code[i] == 0x67
        rexw = code[i] & 0xf8 == 0x48
        i += 1
    op = code[i]
    i += 1
    if op in (0xc4, 0xc5, 0x62):  # VEX with 3 or 2 bytes, EVEX: always a ModRM; an imm8 in map 3 and a few of map 1.
        mp = 1 if op == 0xc5 else code[i] & (0x1f if op == 0xc4 else 7)
        i += {0xc5: 1, 0xc4: 2, 0x62: 3}[op]
        op = code[i]
        i += 1
        if mp not in (1, 2, 3):
            raise ValueError(f'map {mp}')
        if mp == 1 and op == 0x77:  # vzeroupper, vzeroall
            return i - s, None, None
        n, rel = _modrm(code, i)
        return i + n + (mp == 3 or (mp == 1 and op in IMM8_2)) - s, rel, None
    if op == 0x0f:
        op = code[i]
        i += 1
        if op in (0x38, 0x3a):
            n, rel = _modrm(code, i + 1)
            return i + 1 + n + (op == 0x3a) - s, rel, None
        if 0x80 <= op <= 0x8f:  # jcc rel32
            return i + 4 - s, i, None
        if op in INVALID2:
            raise ValueError(f'0f {op:02x}')
        if op in NO_MODRM2:
            return i - s, None, None
        n, rel = _modrm(code, i)
        return i + n + (op in IMM8_2) - s, rel, None
    if op in INVALID1:
        raise ValueError(f'{op:02x}')
    if op in (0xe8, 0xe9):  # call, jmp rel32
        return i + 4 - s, i, None
    if 0x70 <= op <= 0x7f or 0xe0 <= op <= 0xe3 or op == 0xeb:  # jcc, loop, jrcxz, jmp rel8
        return i + 1 - s, None, i
    immz = 2 if opsize else 4
    if op in MODRM1:
        n, rel = _modrm(code, i)
        imm = (op in IMM8_1) + immz * (op in IMMZ_1)
        if op in (0xf6, 0xf7) and code[i] & 0x38 < 0x10:  # test r/m, imm
            imm = 1 if op == 0xf6 else immz
        return i + n + imm - s, rel, None
    if 0xb8 <= op <= 0xbf:
        imm = 8 if rexw else immz
    elif 0xa0 <= op <= 0xa3:  # mov with a 64-bit address
        imm = 4 if addr32 else 8
    elif op in (0xc2, 0xca):
        imm = 2
    elif op == 0xc8:
        imm = 3
    else:
        imm = (op in IMM8_1) + immz * (op in IMMZ_1)
    return i + imm - s, None, None


Ref = namedtuple('Ref', 'at disp end add before read', defaults=(False,))


class Image:
    """A PE32+ file: its header values, its sections, its code section (the first one) and its .pdata function runs."""

    def __init__(self, data):
        pe = struct.unpack_from('<I', data, 0x3c)[0]
        if data[:2] != b'MZ' or data[pe:pe + 4] != b'PE\0\0' or struct.unpack_from('<H', data, pe + 24)[0] != 0x20b:
            raise ValueError('not a PE32+ file')
        count, self.stamp, _, _, opt_size = struct.unpack_from('<HIIIH', data, pe + 6)
        opt = pe + 24
        self.base = struct.unpack_from('<Q', data, opt + 24)[0]
        self.size = struct.unpack_from('<I', data, opt + 56)[0]
        self.sections = []  # (name, va, bytes in the file, executable)
        for k in range(count):
            name, vsize, rva, raw_size, raw, flags = struct.unpack_from('<8sIIII12xI', data, opt + opt_size + 40 * k)
            self.sections.append((name.rstrip(b'\0').decode('latin-1'), self.base + rva,
                                  data[raw:raw + min(vsize, raw_size)], bool(flags & 0x20000000)))
        self.code_name, self.code_va, self.code, _ = self.sections[0]
        pdata_rva, pdata_size = struct.unpack_from('<II', data, opt + 112 + 3 * 8)  # The exception directory.
        pdata = self.at(self.base + pdata_rva, pdata_size)
        self.runs = sorted(struct.unpack_from('<II', pdata, k) for k in range(0, len(pdata) - 11, 12))
        self.starts = [r[0] for r in self.runs]

    def at(self, va, n):
        """The n bytes at va that the file holds (fewer past a section's file data)."""
        for _, start, blob, _ in self.sections:
            if start <= va < start + len(blob):
                return blob[va - start:va - start + n]
        return b''

    def u64(self, va):
        value = self.at(va, 8)
        return struct.unpack('<Q', value)[0] if len(value) == 8 else None

    def is_code(self, va):
        return va is not None and any(start <= va < start + len(blob) for _, start, blob, x in self.sections if x)

    def holders(self, va):
        """The 8-byte aligned places of the data sections that hold va."""
        key, out = struct.pack('<Q', va), []
        for _, start, blob, x in self.sections:
            k = -1
            while not x and (k := blob.find(key, k + 1)) != -1:
                if (start + k) % 8 == 0:
                    out.append(start + k)
        return out

    def run_start(self, i):
        """The code offset where the .pdata function run holding code[i] starts, or None."""
        rva = self.code_va - self.base + i
        k = bisect.bisect_right(self.starts, rva) - 1
        if k >= 0 and self.runs[k][0] <= rva < self.runs[k][1]:
            return self.runs[k][0] - (self.code_va - self.base)
        return None


def instructions(code, start):
    """The instructions from code[start] that end within MAX_LEN bytes, as (end, rel32, rel8) offsets from start (None
    for a field the instruction lacks), up to an int3
    (padding between functions), a jump out of the code section or an opcode decode() refuses."""
    out, i = [], start
    while i < len(code) and code[i] != 0xcc:
        try:
            n, rel, short = decode(code, i)
        except (ValueError, IndexError):
            break
        if i + n - start > MAX_LEN:
            break
        out.append((i + n - start, None if rel is None else rel - start, None if short is None else short - start))
        i += n
        if code[i - n] == 0xe9 and not 0 <= i + struct.unpack_from('<i', code, i - 4)[0] < len(code):
            break  # A jump out of the code section: a protected function's stub, with junk after it.
    return out


def find(code, pattern, mask, stop=None):
    """The offsets where pattern matches code, overlaps included, the bytes under a ? left out; at most stop of them."""
    rx = re.compile(b''.join(b'.' if m == '?' else re.escape(pattern[k:k + 1]) for k, m in enumerate(mask)), re.S)
    out, m = [], rx.search(code)
    while m and len(out) != stop:
        out.append(m.start())
        m = rx.search(code, m.start() + 1)
    return out


def shortest(code, start, at_least=1):
    """(pattern, mask) of the shortest run of whole instructions from code[start], at least at_least bytes long with
    MIN_FIXED bytes to match, that occurs once in code, or None."""
    insns = instructions(code, start)
    if not insns:
        return None
    wild = {r + k for _, r, _ in insns if r is not None for k in range(4)} | {s for *_, s in insns if s is not None}
    pattern = code[start:start + insns[-1][0]]
    mask = ''.join('?' if k in wild else 'x' for k in range(len(pattern)))
    first = next((e for e, *_ in insns if e >= at_least and mask[:e].count('x') >= MIN_FIXED), None)
    if first is None:
        return None
    # Any other place the longer runs match also matches this first one: count how far each of those goes.
    longest = 0
    for at in find(code, pattern[:first], mask[:first]):
        if at == start:
            continue
        n = first
        while n < len(pattern) and at + n < len(code) and (mask[n] == '?' or code[at + n] == pattern[n]):
            n += 1
        longest = max(longest, n)
    end = next((e for e, *_ in insns if e >= first and e > longest), None)
    return None if end is None else (pattern[:end], mask[:end])


def references(image, exact, near):
    """{target: [Ref, ...]}: the instructions of the code section whose rel32 or RIP-relative disp32 gives a target
    (add 0). For a target of near that none gives: those that give the nearest address below it within WINDOW (add the
    distance). When the target holds a pointer to code (a vtable slot), every 8 bytes from that address to the target
    must hold one too. Ref.at is the instruction's offset in the code section, disp and end the field's offset and the
    instruction's length, before the starts of the instructions up to BACK bytes before it, nearest first. Each
    instruction is decoded from the start of its .pdata function run, so bytes that only look like one inside another
    instruction are left out."""
    code, va = image.code, image.code_va
    pages = {a >> 12 for t in near for a in range(t - WINDOW, t + 0x1000, 0x1000)}
    fields = []
    for m in re.finditer(rb'[\x05\x0d\x15\x1d\x25\x2d\x35\x3d\xe8\xe9]', code):  # RIP-relative ModRM, call, jmp
        p = m.start() + 1
        if p + 4 <= len(code):
            to = va + p + 4 + struct.unpack_from('<i', code, p)[0]
            if to in exact or to >> 12 in pages:  # The pages also hold a data address followed by an immediate.
                fields.append(p)
    found = {}
    for field in fields:
        i, seen = image.run_start(field), []
        while i is not None and i < field:
            try:
                n, rel, _ = decode(code, i)
            except (ValueError, IndexError):
                break
            if rel == field:
                before = [s for s in reversed(seen) if i - s <= BACK]
                to = va + i + n + struct.unpack_from('<i', code, field)[0]
                found.setdefault(to, []).append(Ref(i, field - i, n, 0, before))
            seen.append(i)
            i += n
    out = {t: found.get(t, []) for t in exact | near}
    for t in (t for t in near if not out[t]):
        slot = image.is_code(image.u64(t))
        bases = [a for a in found if t - WINDOW <= a < t and (not slot or (t - a) % 8 == 0 and
                                                              all(image.is_code(image.u64(b)) for b in range(a, t, 8)))]
        if bases:
            out[t] = [r._replace(add=t - max(bases)) for r in found[max(bases)]]
    return out


def through(code, refs):
    """(pattern, mask, start, ref) of the shortest signature that holds one of refs' instructions, or None. Each
    instruction's own run is tried first, then the runs that start before it."""
    refs = [refs[k * len(refs) // MAX_REFS] for k in range(MAX_REFS)] if len(refs) > MAX_REFS else refs
    best = None
    for r in refs:
        sig = shortest(code, r.at, r.end)
        if sig and (best is None or len(sig[0]) < len(best[0])):
            best = (*sig, r.at, r)
    for r in refs if best is None else ():
        for s in r.before:
            sig = shortest(code, s, r.at - s + r.end)
            if sig:
                if best is None or len(sig[0]) < len(best[0]):
                    best = (*sig, s, r)
                break
    return best


def matches(image, entry, stop=None):
    """The code offsets where entry's pattern matches in image, at most stop of them."""
    return find(image.code, bytes.fromhex(entry['pattern'].replace('??', '00')), entry['mask'], stop)


def follow(image, entry, at):
    """The addresses entry's signature gives when its pattern matches at code offset at: none when a field lies
    outside the file, one per place that holds the match for a holder, else one."""
    va, ref = image.code_va + at, entry.get('ref')
    while ref and va is not None:
        field = image.at(va + ref['disp'], 4)
        va = va + ref['end'] + struct.unpack('<i', field)[0] + ref['add'] if len(field) == 4 else None
        va = image.u64(va) if ref.get('read') and va is not None else va
        ref = ref.get('then')
    if va is None:
        return []
    if 'holder' in entry:
        return [p + entry['holder']['add'] for p in image.holders(va)]
    return [va]


def resolve(image, entry):
    """The address entry's signature gives in image, or None when it does not match exactly once."""
    at = matches(image, entry, stop=2)
    got = follow(image, entry, at[0]) if len(at) == 1 else []
    return got[0] if len(got) == 1 else None


def holder(image, address):
    """(pattern, mask, add) for a vtable slot that no instruction finds: the run of the code that the nearest slot of
    its vtable holds, when no other place holds that code's address, with add the distance from that slot to address."""
    slots = []
    for s, step in ((address, 8), (address - 8, -8)):
        while abs(s - address) <= WINDOW and image.is_code(image.u64(s)):
            slots.append(s)
            s += step
    for s in sorted(slots, key=lambda s: (abs(s - address), s)):
        value = image.u64(s)
        sig = image.holders(value) == [s] and shortest(image.code, value - image.code_va)
        if sig:
            return (*sig, address - s)
    return None


def fields(va, start, r):
    """The "ref" fields of Ref r for a signature that starts at code offset start."""
    out = {'from': f'{va + r.at:#x}', 'disp': r.at - start + r.disp, 'end': r.at - start + r.end, 'add': r.add}
    return {**out, 'read': True} if r.read else out


def signatures(image, entries):
    """{address: (pattern, mask, extra fields)} for the entries that get a signature. In order: the address's own run;
    an instruction that holds the address, or a place that holds it; for a vtable slot that holds code, that code's own
    run or the one of a neighbour slot; for an instruction in identical copies of a function (templates), a call to
    its copy."""
    code, va = image.code, image.code_va
    sigs, direct = {}, {}
    for a, e in entries.items():
        if e['kind'] in ('function', 'code') and 0 <= int(a, 16) - va < len(code):
            direct[a] = shortest(code, int(a, 16) - va)
            if direct[a]:
                sigs[a] = (*direct[a], {})
    exact = {int(a, 16) for a, e in entries.items() if e['kind'] in SIGNED and a not in sigs}
    held = {a: image.holders(a) for a in exact if image.is_code(a)}  # Code only a vtable may point to.
    near = {int(a, 16) for a, e in entries.items() if e['kind'] in ('global', 'rdata')}
    refs = references(image, exact, near | {h for hs in held.values() for h in hs})
    copies = {}
    for address in sorted(exact):
        a = f'{address:#x}'
        tries = refs[address] or [r._replace(read=True) for h in held.get(address, ()) for r in refs[h]]
        best = through(code, tries) or (None if image.is_code(address) else holder(image, address))
        if best and len(best) == 4:
            sigs[a] = (best[0], best[1], {'ref': fields(va, best[2], best[3])})
        elif best:
            sigs[a] = (best[0], best[1], {'holder': {'add': best[2]}})
        else:
            copies[a] = [(image.run_start(r.at), r) for r in tries if image.run_start(r.at) is not None]
    calls = references(image, {va + run for c in copies.values() for run, _ in c}, set()) if copies else {}
    for a, c in copies.items():
        for run, r in c:
            best = through(code, calls[va + run])
            if best:
                sigs[a] = (best[0], best[1], {'ref': {**fields(va, best[2], best[3]), 'then': fields(va, run, r)}})
                break
    return sigs


def build(image, entries):
    """entries with a signature added to each function, code, global and rdata address. Returns (entries, failures)."""
    sigs, out, failed = signatures(image, entries), {}, []
    for a, entry in entries.items():
        entry = out[a] = dict(entry)
        if entry['kind'] not in SIGNED:
            continue
        if a not in sigs:
            failed.append(f'{a}: no unique signature')
            continue
        pattern, mask, extra = sigs[a]
        entry.update(pattern=' '.join('??' if m == '?' else f'{b:02x}' for b, m in zip(pattern, mask)), mask=mask,
                     **extra)
        got = resolve(image, entry)
        if got != int(a, 16):
            failed.append(f'{a}: the signature gives {got and hex(got)}')
    return out, failed


def pinned():
    """(TimeDateStamp, SizeOfImage) of the build check_build() accepts."""
    m = re.search(r'kTimeDateStamp = (0x[0-9a-f]+), kSizeOfImage = (0x[0-9a-f]+)', ENGINE.read_text(encoding='utf-8'))
    return int(m.group(1), 16), int(m.group(2), 16)


def dump(build_id, entries):
    lines = [f'    {json.dumps(a)}: {json.dumps(e)}' for a, e in entries.items()]
    return '{\n  "build": ' + json.dumps(build_id) + ',\n  "addresses": {\n' + ',\n'.join(lines) + '\n  }\n}\n'


def main(argv):
    if len(argv) != 2:
        sys.exit(__doc__.rsplit('Run: ', 1)[1])
    image = Image(Path(argv[1]).read_bytes())
    if (image.stamp, image.size) != pinned():
        sys.exit(f'{argv[1]}: TimeDateStamp {image.stamp:#x}, SizeOfImage {image.size:#x}: not the pinned build')
    with open(addresses.SIGNATURES, encoding='utf-8') as f:
        doc = json.load(f)
    with open(addresses.UE4SS, encoding='utf-8') as f:
        ue4ss = json.load(f)
    if ue4ss['build'] != doc['build']:  # Its addresses would be another build's, signed on this executable.
        sys.exit(f'{addresses.UE4SS} is for build {ue4ss["build"]}, {addresses.SIGNATURES} for build {doc["build"]}: '
                 'write the new addresses and build into both (docs/dev/porting.md, step 4)')
    names = {}
    for u in addresses.scan():
        names.setdefault(f'{u.address:#x}', set()).add(u.name)
    entries = {a: {'kind': e['kind'], 'ghidra': e['ghidra'], 'name': ', '.join(sorted(names.get(a, ())))}
               for a, e in doc['addresses'].items()}  # What Ghidra showed stays; the rest is made again.
    targets = {a: {k: e[k] for k in ('kind', 'ghidra', 'name')} for a, e in ue4ss['addresses'].items()}
    entries, failed = build(image, {**targets, **entries})  # One pass over the code for both files.
    addresses.SIGNATURES.write_text(dump(doc['build'], {a: entries[a] for a in doc['addresses']}), encoding='utf-8')
    addresses.UE4SS.write_text(dump(ue4ss['build'], {a: {**entries[a], **t} for a, t in targets.items()}),
                               encoding='utf-8')
    signed = [e for e in entries.values() if 'pattern' in e]
    print(f'{len(signed)} signatures in {image.code_name}, {sum("ref" in e for e in signed)} of them through a '
          f'referencing instruction; {len(failed)} failures')
    for line in failed:
        print(line)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
