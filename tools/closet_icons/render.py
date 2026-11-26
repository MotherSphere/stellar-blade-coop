#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Renders Stellar Closet's glyphs: each SVG of tools/closet_icons/svg/ (or the names given) to
mod/StellarCoop/Scripts/closet/ui/icons/<name>.png, transparent 8-bit RGBA, with a headless Chromium browser: Microsoft
Edge, else Google Chrome, else msedge, chrome, chromium or google-chrome on PATH. A small glyph (SMALL: the origin
badges, the camera modes, the light presets) is 64 px, a tile glyph 256 px. The root <svg> of the page it loads gets a
width and height of that size: with only a viewBox the window's own viewport is wider. The glyph then comes out at twice
the size and cropped. Prints each file it writes. Installs nothing.
Run: python3 -I tools/closet_icons/render.py [name ...]"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SVG = HERE / 'svg'
OUT = ROOT / 'mod/StellarCoop/Scripts/closet/ui/icons'
SMALL = {'original', 'custom', 'camera_region', 'camera_free', 'light_game', 'light_studio', 'light_warm', 'light_cool',
         'light_rim'}
BROWSERS = (r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
            r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
            r'C:\Program Files\Google\Chrome\Application\chrome.exe', 'msedge', 'chrome', 'chromium', 'google-chrome')


def size(name):
    """The PNG's width and height in pixels."""
    return 64 if name in SMALL else 256


def browser():
    for b in BROWSERS:
        found = shutil.which(b) or (Path(b).is_file() and b)
        if found: return found
    sys.exit('No Edge or Chrome found: the SVGs need a Chromium browser to render.')


def main(names):
    exe = browser()
    svgs = [SVG / f'{name}.svg' for name in names] if names else sorted(SVG.glob('*.svg'))
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        for svg in svgs:
            n = size(svg.stem)
            page = Path(tmp) / svg.name
            page.write_text(svg.read_text(encoding='utf-8').replace('<svg ', f'<svg width="{n}" height="{n}" ', 1),
                            encoding='utf-8')
            png = OUT / f'{svg.stem}.png'
            subprocess.run([exe, '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
                            '--disable-extensions', '--hide-scrollbars', '--default-background-color=00000000',
                            f'--window-size={n},{n}', '--force-device-scale-factor=1',
                            f'--user-data-dir={Path(tmp) / "profile"}', f'--screenshot={png}', page.as_uri()],
                           check=True, capture_output=True, timeout=60)
            print(png.relative_to(ROOT).as_posix(), flush=True)


if __name__ == '__main__':
    main(sys.argv[1:])
