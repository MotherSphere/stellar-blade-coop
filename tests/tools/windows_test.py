#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""install_test, save_guard_test and story_lines_test as Python runs them on Windows, simulated here: text files and
subprocess text in cp1252, '\\n' written as CRLF and no signal.alarm. Symbolic links are first refused with WinError
1314 (Windows without Developer Mode), then allowed where this machine can make links. Without them install_test and
save_guard_test print a 'not tested' line for each check they skip. Paths keep this machine's separators.
Run: python3 tests/tools/windows_test.py"""
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Runs in the child before the test. argv: the test, then 'links' or 'no-links'.
WINDOWS = r'''
import builtins, errno, io, os, runpy, signal, subprocess, sys
real_open = io.open

def windows_open(file, mode='r', buffering=-1, encoding=None, errors=None, newline=None, closefd=True, opener=None):
    if 'b' not in mode:  # Python 3.13 on Windows: the ANSI code page, '\n' written as CRLF.
        if encoding in (None, 'locale'): encoding = 'cp1252'
        if newline is None and set(mode) & set('wax'): newline = '\r\n'
    return real_open(file, mode, buffering, encoding, errors, newline, closefd, opener)

def no_privilege(*args, **kwargs):
    error = OSError(errno.EPERM, 'A required privilege is not held by the client')
    error.winerror = 1314
    raise error

# Out of UTF-8 mode, as on Windows, under any locale here. File names stay UTF-8, as on Windows.
io.text_encoding = lambda encoding, stacklevel=2: 'locale' if encoding is None else encoding
io.open = builtins.open = windows_open
subprocess._text_encoding = lambda: 'cp1252'
vars(signal).pop('alarm', None)
test, links = sys.argv[1:]
if links == 'no-links': os.symlink = no_privilege
sys.argv = [test]
runpy.run_path(test, run_name='__main__')
'''
SKIPPED = {'install_test': 2, 'save_guard_test': 2, 'story_lines_test': 0}  # 'not tested' lines without links.

with tempfile.TemporaryDirectory() as tmp:  # On Windows without Developer Mode the 'links' run has none either.
    try:
        (Path(tmp) / 'link').symlink_to(tmp)
        can_link = True
    except OSError:
        can_link = False

for links in ('no-links', 'links'):
    for test, count in SKIPPED.items():
        run = subprocess.run([sys.executable, '-I', '-c', WINDOWS, ROOT / f'tests/tools/{test}.py', links], cwd=ROOT,
                             capture_output=True, encoding='utf-8', errors='replace')
        assert run.returncode == 0 and run.stdout.endswith(f'{test}: ok\n'), (test, links, run.stdout, run.stderr)
        skipped = [line for line in run.stdout.splitlines() if 'not tested' in line]
        assert len(skipped) == (count if links == 'no-links' or not can_link else 0), (test, links, skipped)

print('windows_test: ok')
