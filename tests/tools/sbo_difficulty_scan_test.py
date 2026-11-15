#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""The native part calls SB's difficulty setter 0x141cf3180 in one place only: R8, inside case SboStep::r7, once the
return's reload is over. In game and outside a type-5 zone the setter makes SB reload the save (0x141cf2610 with its
0.5 s timer), and on 2026-11-12 the call E9 made right after the lobby's URL warp did that and ran over the warp. A
text scan: `sbo::kSetDifficulty)` must appear exactly once under native/src, in that case. It first runs on planted
trees, so the rule cannot pass vacuously, then on this repository.
Run: python3 tests/tools/sbo_difficulty_scan_test.py"""
import re
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CALL = 'sbo::kSetDifficulty)'
CASE = re.compile(r'case SboStep::(\w+):')


def scan(root):
    """Every violation under root/native/src, as '<file>:<line>: <what>'."""
    out, calls = [], 0
    for path in sorted(p for p in (root / 'native/src').rglob('*') if p.is_file()):
        text, rel = path.read_bytes().decode('utf-8', 'replace'), path.relative_to(root).as_posix()
        at = text.find(CALL)
        while at >= 0:
            calls += 1
            cases = CASE.findall(text, 0, at)  # The last case label before the call is the one it sits in.
            if not cases or cases[-1] != 'r7':
                out.append(f'{rel}:{text.count(chr(10), 0, at) + 1}: {CALL} outside case SboStep::r7')
            at = text.find(CALL, at + 1)
    if calls != 1: out.append(f'native/src: {calls} {CALL} calls, expected 1')
    return out


R7 = 'case SboStep::r7: {\n  game_function<SetDifficulty>(sbo::kSetDifficulty)(c, t, 0);\n}\n'
E9 = 'case SboStep::e9: {\n  game_function<SetDifficulty>(sbo::kSetDifficulty)(c, 0, 0);\n}\n'
PLANTS = [(0, R7), (1, ''), (2, R7 + E9), (1, R7 + R7), (1, E9), (1, 'game_function<S>(sbo::kSetDifficulty)(c);\n')]
for want, text in PLANTS:
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / 'native/src/glue').mkdir(parents=True)
        (Path(tmp) / 'native/src/glue/sbo_game.inc').write_text(text)
        got = scan(Path(tmp))
        assert len(got) == want, (text, got)

assert scan(ROOT) == [], scan(ROOT)
print('sbo_difficulty_scan_test: ok')
