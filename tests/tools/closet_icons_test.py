#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""The closet's glyphs (tools/closet_icons/): each SVG of tools/closet_icons/svg/ has its PNG in
mod/StellarCoop/Scripts/closet/ui/icons/ at the size render.py gives it (64 px for a small glyph, 256 px for a tile
glyph) in 8-bit RGBA. Each PNG there has its SVG. Each SVG has the 256 viewBox, the stroke width of its kind (8 for a
tile glyph, 16 for a small one), round caps and joins, and no text. The PNG header is read with struct: no Pillow and
no browser, so it runs anywhere.
Run: python3 tests/tools/closet_icons_test.py"""
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/closet_icons'))
import render  # noqa: E402

svgs = {p.stem: p.read_text(encoding='utf-8') for p in render.SVG.glob('*.svg')}
pngs = {p.stem: p.read_bytes() for p in render.OUT.glob('*.png')}
assert sorted(svgs) == sorted(pngs), sorted(set(svgs) ^ set(pngs))
assert len(svgs) == 51, len(svgs)  # 41 tile glyphs, none and 9 small glyphs.
assert sorted(name for name in svgs if render.size(name) == 64) == sorted(render.SMALL), sorted(render.SMALL)
for name, svg in sorted(svgs.items()):
    size = render.size(name)
    head = pngs[name][:26]
    assert head[:8] == b'\x89PNG\r\n\x1a\n', name
    assert struct.unpack('>IIBB', head[16:26]) == (size, size, 8, 6), (name, struct.unpack('>IIBB', head[16:26]))
    assert 'viewBox="0 0 256 256"' in svg, name
    assert f'stroke-width="{16 if size == 64 else 8}"' in svg, name
    assert 'stroke-linecap="round"' in svg and 'stroke-linejoin="round"' in svg, name
    assert '<text' not in svg, name
print('closet_icons_test: ok')
