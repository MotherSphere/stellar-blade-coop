#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/new_module.py on a copy of the trees it reads and edits, in a temporary directory: each refusal exits with 2
and changes nothing, --dry-run changes nothing, then a Lua module (world/nm_lanterns) and a native one in a nested
category (online/modes/nm_duel) are made with every file and every registration in place, the tool's own checks pass
(modules_test.py and the module's Lua tests), each file it writes has LF ends and part 11 of
tests/tools/install_test.py, its shipped list, passes on the copy. No git needed. It runs on Windows too.
Run: python3 tests/tools/new_module_test.py"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / 'tools/new_module.py'
S = 'mod/StellarCoop/Scripts'
COPY = ('mod', 'native/src', 'tests/lua', 'tests/native', 'tests/tools/modules_test.py', 'tests/tools/install_test.py',
        'tools/install.py', 'docs', 'LICENSE', 'NOTICE', 'INSTALL.md', 'EXCLUDED-PARTIES.md')
LICENSE = 'Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors'


def run(root, *args, env=None):
    done = subprocess.run([sys.executable, '-I', str(TOOL), *args, '--root', str(root)], capture_output=True,
                          text=True, env=env)
    return done.returncode, done.stdout + done.stderr


def files(root):
    return {p.relative_to(root).as_posix(): p.read_bytes() for p in sorted(root.rglob('*')) if p.is_file()}


def text(root, rel): return (root / rel).read_text(encoding='utf-8')


def modules(root):
    main = text(root, f'{S}/main.lua')
    return re.findall(r"'([\w.]+)'", re.search(r'MODULES=(\{.*?\})', main, re.S).group(1))


def languages(root):
    return re.findall(r"(?m)^T(?:\.\w+|\['[\w-]+'\])=require\('ui\.text\.([\w-]+)'\)",
                      text(root, f'{S}/ui/text.lua'))


def shipped(root):
    """install_test.py's part 11 on the copy, after its setup: the shipped list. Parts 1 to 10 test install.py, which
    the tool does not change. Part 12 on needs git."""
    code = text(root, 'tests/tools/install_test.py')
    part = code[:code.index('\n    # 1. ')] + code[code.index('\n    # 11. '):code.index('\n    # 12. ')]
    # !a: ASCII only. Python reads a script on stdin as UTF-8, while text=True writes it in the locale's encoding
    # (cp1252 on most Windows): a temporary folder under C:\Users\Léa would not parse.
    run = f"exec(compile({part!a}, 'install_test.py', 'exec'), " \
          f"{{'__file__': {str(root / 'tests/tools/install_test.py')!a}, '__name__': '__main__'}})"
    # On stdin: a Windows command line holds at most 32767 characters.
    done = subprocess.run([sys.executable, '-'], input=run, cwd=root, capture_output=True, text=True)
    assert done.returncode == 0, done.stdout + done.stderr


def refused(root, why, *args, env=None):
    before = files(root)
    code, out = run(root, *args, env=env)
    assert code == 2 and why in out, (args, code, out)
    assert files(root) == before, f'{args} changed files'


with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp) / 'repo'
    for rel in COPY:
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        if (ROOT / rel).is_dir(): shutil.copytree(ROOT / rel, root / rel)
        else: shutil.copy2(ROOT / rel, root / rel)
    langs = languages(root)
    assert len(langs) == 22 and 'en' in langs and 'zh-Hant' in langs, langs
    count = len(modules(root))

    # 1. Refusals: exit code 2, the reason said, nothing changed.
    refused(root, 'bad module name', 'world/Lanterns', '--title', 'Lanterns')
    refused(root, 'bad module name', 'world/9lives', '--title', 'Lanterns')
    refused(root, 'bad module name', 'world/end', '--title', 'Lanterns')  # A Lua keyword.
    refused(root, 'bad module name', 'world/class', '--title', 'Lanterns', '--native')  # A C++ keyword.
    refused(root, 'bad module name', 'nm_lanterns', '--title', 'Lanterns')
    refused(root, 'unknown category space', 'space/nm_lanterns', '--title', 'Lanterns')
    refused(root, 'unknown category online/lobby', 'online/lobby/nm_lanterns', '--title', 'Lanterns')
    refused(root, 'already exists', 'world/teamshop', '--title', 'Team shop')
    refused(root, 'already exists', 'online/modes', '--title', 'Modes')
    refused(root, 'coop bike is already a console word', 'world/bike', '--title', 'Lanterns')
    # A word online/partner/commands.lua makes in a loop: only main.lua's load names it.
    refused(root, 'coop replay is already a console word', 'world/replay', '--title', 'Replays')
    refused(root, 'has a namespace pose already', 'world/pose', '--title', 'Poses', '--native')  # In native/src.
    # The whole environment but PATH: Python does not start on Windows without SYSTEMROOT.
    refused(root, 'lua5.4 did not start', 'world/nm_lanterns', '--title', 'Lanterns', env={**os.environ, 'PATH': ''})
    refused(root, 'bad title', 'world/nm_lanterns', '--title', 'Lanterns | shop')
    refused(root, 'bad title', 'world/nm_lanterns', '--title', 'L' * 41)
    refused(root, 'bad title', 'world/nm_lanterns', '--title', ' Lanterns')
    empty = Path(tmp) / 'empty'
    empty.mkdir()
    refused(empty, 'not a Stellar Blade Online checkout', 'world/nm_lanterns', '--title', 'Lanterns')
    # A missing anchor in one file it edits: refused before any file is written.
    # Bytes in and out: write_text would write CRLF ends on Windows.
    saved = (root / 'tests/lua/ui/text_test.lua').read_bytes()
    (root / 'tests/lua/ui/text_test.lua').write_bytes(saved.replace(b'MODULE_KEYS==', b'MODULE_KEYS>='))
    refused(root, 'tests/lua/ui/text_test.lua', 'world/nm_lanterns', '--title', 'Lanterns')
    (root / 'tests/lua/ui/text_test.lua').write_bytes(saved)
    saved = (root / 'tests/lua/main/fixture.lua').read_bytes()  # main.lua does not load: its words are unknown.
    (root / 'tests/lua/main/fixture.lua').write_bytes(b"error('broken')\n" + saved)
    refused(root, 'main.lua does not load', 'world/nm_lanterns', '--title', 'Lanterns')
    (root / 'tests/lua/main/fixture.lua').write_bytes(saved)

    # 2. --dry-run names every file and every edit. It changes nothing.
    before = files(root)
    code, out = run(root, 'world/nm_lanterns', '--title', 'Street lanterns', '--dry-run')
    assert code == 0 and files(root) == before, out
    made = {f'{S}/world/nm_lanterns/wiring.lua', f'{S}/world/nm_lanterns/commands.lua',
            'tests/lua/world/nm_lanterns/off_test.lua', 'tests/lua/world/nm_lanterns/nm_lanterns_test.lua',
            'docs/world/nm_lanterns.md'}
    edited = {f'{S}/main.lua', 'tests/lua/ui/text_test.lua', 'tests/tools/install_test.py', 'docs/dev/structure.md',
              *(f'{S}/ui/text/{c}.lua' for c in langs)}
    for rel in made: assert f'Would create {rel}\n' in out, (rel, out)
    for rel in edited: assert f'Would edit {rel}: ' in out, (rel, out)
    assert 'Dry run: nothing changed.' in out and 'native/src/' not in out, out

    # 3. A Lua module: its files, its registrations, the tool's checks; nothing else changed.
    code, out = run(root, 'world/nm_lanterns', '--title', "Lanterns' light")
    assert code == 0, out
    for line in ('modules_test: ok', 'world.nm_lanterns_off_test ok', 'nm_lanterns_test ok', 'ui_text_test ok',
                 'main/ui.lua'):
        assert line in out, (line, out)
    after = files(root)
    assert set(after) - set(before) == made, sorted(set(after) - set(before))
    assert {rel for rel in before if after.get(rel) != before[rel]} == edited
    assert not [rel for rel in made | edited if b'\r' in after[rel]], 'the tool writes LF ends on every platform'
    for rel in made - {'docs/world/nm_lanterns.md'}:
        assert LICENSE in text(root, rel).splitlines()[0], rel
    wiring = text(root, f'{S}/world/nm_lanterns/wiring.lua')
    assert 'uses={},\nexports={},\nnew=function(M)\n' in wiring, wiring
    assert "require('world.nm_lanterns.commands').new({})" in wiring, wiring
    assert text(root, 'tests/lua/world/nm_lanterns/off_test.lua').endswith(
        "dofile('tests/lua/main/isolation.lua')('world.nm_lanterns')\nprint('world.nm_lanterns_off_test ok')\n")
    assert text(root, 'docs/world/nm_lanterns.md').startswith("# Lanterns' light\n")
    assert modules(root)[-1] == 'world.nm_lanterns' and len(modules(root)) == count + 1
    for c in langs:  # The English name in every table, in double quotes for its apostrophe.
        table = re.search(r'modules=\{[^}]*\}', text(root, f'{S}/ui/text/{c}.lua')).group()
        assert table.endswith('''['world.nm_lanterns']="Lanterns' light"}'''), (c, table)
    assert f'assert(MODULE_KEYS=={count + 1},' in text(root, 'tests/lua/ui/text_test.lua')
    install = text(root, 'tests/tools/install_test.py')
    assert "'world/nm_lanterns/commands'," in install and re.search(r"'world/nm_lanterns'\)\),", install), install
    structure = text(root, 'docs/dev/structure.md')
    assert ("| `world.nm_lanterns` | Lanterns' light | `world/nm_lanterns/` | none | "
            "[Lanterns' light](../world/nm_lanterns.md) | |\n" in structure), structure
    for rel in edited | made:  # Each new line within 120 columns, the doc's table rows aside.
        old = set(before[rel].decode().splitlines()) if rel in before else set()
        long = [line for line in text(root, rel).splitlines()
                if line not in old and len(line) > 120 and not line.startswith('|')]
        assert not long, (rel, long)
    shipped(root)
    refused(root, 'already exists', 'world/nm_lanterns', '--title', 'Lanterns')

    # 4. A native module in a nested category: its header and native test too, the hub's steps printed, not made.
    before = files(root)
    tick = text(root, 'native/src/glue/tick.cpp')
    code, out = run(root, 'online/modes/nm_duel', '--title', 'Duels', '--native')
    assert code == 0 and 'modules_test: ok' in out and 'nm_duel_test ok' in out, out
    assert 'native/src/glue/tick.cpp' in out and text(root, 'native/src/glue/tick.cpp') == tick, out
    after = files(root)
    assert set(after) - set(before) == {
        f'{S}/online/modes/nm_duel/wiring.lua', f'{S}/online/modes/nm_duel/commands.lua',
        'tests/lua/online/modes/nm_duel/off_test.lua', 'tests/lua/online/modes/nm_duel/nm_duel_test.lua',
        'docs/online/modes/nm_duel.md', 'native/src/online/modes/nm_duel/nm_duel.h',
        'tests/native/online/modes/nm_duel/nm_duel_test.cpp'}, sorted(set(after) - set(before))
    header = text(root, 'native/src/online/modes/nm_duel/nm_duel.h')
    assert header.startswith('// ' + LICENSE) and '#pragma once' in header and 'namespace coop::nm_duel {' in header
    native_test = text(root, 'tests/native/online/modes/nm_duel/nm_duel_test.cpp')
    assert '#include "online/modes/nm_duel/nm_duel.h"' in native_test, native_test
    assert modules(root)[-2:] == ['world.nm_lanterns', 'online.modes.nm_duel']
    assert "['online.modes.nm_duel']='Duels'" in text(root, f'{S}/ui/text/ja.lua')
    assert f'assert(MODULE_KEYS=={count + 2},' in text(root, 'tests/lua/ui/text_test.lua')
    assert ('| `online.modes.nm_duel` | Duels | `online/modes/nm_duel/` | `online/modes/nm_duel/` | '
            '[Duels](../online/modes/nm_duel.md) | |\n' in text(root, 'docs/dev/structure.md'))
    shipped(root)
print('new_module_test: ok')
