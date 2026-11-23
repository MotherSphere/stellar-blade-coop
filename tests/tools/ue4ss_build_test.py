#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""tools/ue4ss_build.py without network, git or the toolchain: the patch file it applies, the commit check, the clone,
configure and build command lines, the variables that keep local paths out of the DLL, the refusals that come before
any clone and a whole run over a fake subprocess.run. Its default output is where tools/ue4ss.py looks for UE4SS.dll.
Run: python3 tests/tools/ue4ss_build_test.py"""
import contextlib
import hashlib
import io
import os
import sys
import tempfile
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import ue4ss  # noqa: E402
import ue4ss_build as tool  # noqa: E402


def stop(fn, *args):
    """The message fn(*args) exits with."""
    with contextlib.redirect_stdout(io.StringIO()):
        try:
            fn(*args)
        except SystemExit as error:
            return str(error.code)
    raise AssertionError(f'{fn.__name__}{args} did not stop')


# The one patch: git format-patch output of commit 9a61a393 on tag v4.0.0. git am reads the mail header, the message
# up to '---' and the diffs; the note below '---' stays out of the commit.
assert sorted(p.name for p in (ROOT / 'ue4ss/patches').iterdir()) == [tool.PATCH.name]
patch = tool.PATCH.read_text(encoding='utf-8')
assert patch.startswith('From 9a61a393dec17696dc7d2cf4094e2ce13edcf7b4 Mon Sep 17 00:00:00 2001\n'), patch[:60]
SUBJECT = "fix(Lua): don't block loading threads on\n m_thread_actions_mutex in the StaticConstructObject hook"
assert f'\nSubject: [PATCH] {SUBJECT}\n' in patch, patch[:300]
message, rest = patch.split('\n---\n', 1)
assert 'https://github.com/UE4SS-RE/RE-UE4SS/issues/1504' in rest.split('\n UE4SS/include/', 1)[0], rest[:400]
assert 'diff --git' not in message and '\r' not in patch
diffs = [line.split(' b/')[1] for line in patch.splitlines() if line.startswith('diff --git ')]
assert diffs == ['UE4SS/include/Mod/LuaMod.hpp', 'UE4SS/src/Mod/LuaMod.cpp', 'UE4SS/src/UE4SSProgram.cpp'], diffs

# The tag must be the release's commit: another one is refused with both hashes.
assert tool.COMMIT == '30afe5fff94a94c2313e220b2002059a080da9a0'
assert tool.check_commit(tool.COMMIT + '\n') is None
assert stop(tool.check_commit, 'f' * 40 + '\n') == (
    f'Tag v4.0.0 is commit {"f" * 40}, not {tool.COMMIT}: refused. Nothing was built.')

# Clone, configure and build. The submodule deps/first/Unreal has an SSH URL: both insteadOf rules send it over https.
work = Path('/w')
assert tool.clone(work / 'src') == [
    'git', '-c', 'url.https://github.com/.insteadOf=git@github.com:',
    '-c', 'url.https://github.com/.insteadOf=ssh://git@github.com/', 'clone', '--branch', 'v4.0.0',
    '--recurse-submodules', '--shallow-submodules', 'https://github.com/UE4SS-RE/RE-UE4SS.git', '/w/src']
assert tool.configure(work, '/usr/bin/llvm-ml') == [
    'cmake', '-S', '/w/src', '-B', '/w/build-rel', '-G', 'Ninja', '-DCMAKE_BUILD_TYPE=Game__Shipping__Win64',
    '-DCMAKE_TOOLCHAIN_FILE=/w/src/cmake/toolchains/xwin-clang-cl-toolchain.cmake',
    '-DCMAKE_ASM_MASM_COMPILER:FILEPATH=/usr/bin/llvm-ml', '-DCMAKE_ASM_MASM_FLAGS:STRING=-m64']
# Only the UE4SS target: the proxy target would run proxy_generator.exe, a Windows program.
assert tool.build(work) == ['cmake', '--build', '/w/build-rel', '--target', 'UE4SS', '-j6']

# The flags go through the environment, never -DCMAKE_CXX_FLAGS: the toolchain file adds its include flags to them.
# Each local folder is mapped to a short name, the PDB path is only its name, the link is reproducible.
env = tool.environment(work, {'PATH': '/bin', 'XWIN_DIR': '/x', 'RUSTUP_HOME': '/r', 'CFLAGS': '-O0'})
flags = ('/clang:-ffile-prefix-map=/w/src=src /clang:-ffile-prefix-map=/w/build-rel=build '
         '/clang:-ffile-prefix-map=/x=xwin')
assert env == {'PATH': '/bin', 'XWIN_DIR': '/x', 'RUSTUP_HOME': '/r', 'CARGO_HOME': '/w/cargo-home',
               'CMAKE_BUILD_PARALLEL_LEVEL': '6', 'CARGO_BUILD_JOBS': '6',
               'RUSTFLAGS': '--remap-path-prefix=/w/src=src --remap-path-prefix=/w/cargo-home=cargo '
                            '--remap-path-prefix=/r=rustup',
               'CFLAGS': flags, 'CXXFLAGS': flags, 'LDFLAGS': '/PDBALTPATH:UE4SS.pdb /Brepro'}, env
home = tool.environment(work, {})
assert (home['XWIN_DIR'], home['RUSTFLAGS'].rsplit(' ', 1)[1]) == (
    str(Path.home() / '.local/share/xwin'), f'--remap-path-prefix={Path.home() / ".rustup"}=rustup'), home

# The default output is the file tools/ue4ss.py packages.
assert tool.WORK / tool.DLL == ue4ss.DLL, (tool.WORK / tool.DLL, ue4ss.DLL)

# main with a fake subprocess.run and fake tools on PATH: nothing reaches the network or the toolchain, even when a
# check below fails to stop it.
calls = []


def no_command(cmd, **kwargs):
    raise AssertionError(f'ran {cmd}')


def fake_run(cmd, **kwargs):
    """Records each command with its env. rev-parse answers commit; the build writes a made-up DLL."""
    calls.append((cmd, kwargs.get('env')))
    if cmd[:2] == ['cmake', '--build']:
        (Path(cmd[2]) / 'Game__Shipping__Win64/bin').mkdir(parents=True)
        (Path(cmd[2]) / 'Game__Shipping__Win64/bin/UE4SS.dll').write_bytes(b'built')
    return types.SimpleNamespace(stdout=commit + '\n')


saved = tool.subprocess, tool.shutil, os.environ.get('XWIN_DIR')
with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp).resolve()
    try:
        tool.subprocess = types.SimpleNamespace(run=no_command)
        tool.shutil = types.SimpleNamespace(which=lambda name: f'/usr/bin/{name}')
        # Refusals before any command: a folder with something in it, a path with a space, extra arguments, no xwin.
        (tmp / 'used/src').mkdir(parents=True)
        assert stop(tool.main, ['ue4ss_build.py', str(tmp / 'used')]) == (
            f'{tmp / "used"} is not empty: pick a new work folder or empty it first. Nothing was built.')
        assert stop(tool.main, ['ue4ss_build.py', str(tmp / 'a b')]) == (
            f'{tmp / "a b"} has a space in its path: pick another work folder.')
        assert not (tmp / 'a b').exists()
        assert stop(tool.main, ['ue4ss_build.py', 'a', 'b']).startswith('python3 tools/ue4ss_build.py')
        assert stop(tool.main, ['ue4ss_build.py', '--help']).startswith('python3 tools/ue4ss_build.py')
        tool.shutil = types.SimpleNamespace(which=lambda name: None if name == 'llvm-ml' else f'/usr/bin/{name}')
        assert stop(tool.main, ['ue4ss_build.py', str(tmp / 'new')]) == 'Missing on PATH: llvm-ml. Nothing was built.'
        tool.shutil = types.SimpleNamespace(which=lambda name: f'/usr/bin/{name}')
        os.environ['XWIN_DIR'] = str(tmp / 'no-xwin')
        assert stop(tool.main, ['ue4ss_build.py', str(tmp / 'new')]) == (
            f'No xwin CRT and SDK at {tmp / "no-xwin"} (set XWIN_DIR). Nothing was built.')
        assert not (tmp / 'new').exists()
        # A moved tag stops after the clone, before git am.
        os.environ['XWIN_DIR'] = str(tmp)
        tool.subprocess, commit = types.SimpleNamespace(run=fake_run), 'f' * 40
        assert stop(tool.main, ['ue4ss_build.py', str(tmp / 'moved')]).startswith('Tag v4.0.0 is commit ffff')
        assert [cmd[1:3] for cmd, _ in calls] == [['-c', 'url.https://github.com/.insteadOf=git@github.com:'],
                                                  ['-C', str(tmp / 'moved/src')]], calls
        # The whole run: clone, commit check, git am, configure and build with the variables, then the DLL's hash.
        calls.clear()
        commit, work = tool.COMMIT, tmp / 'work'
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            tool.main(['ue4ss_build.py', str(work)])
        env = tool.environment(work, dict(os.environ))
        assert calls == [(tool.clone(work / 'src'), None),
                         (['git', '-C', str(work / 'src'), 'rev-parse', 'HEAD'], None),
                         (['git', '-C', str(work / 'src'), 'am', str(tool.PATCH)], None),
                         (tool.configure(work, '/usr/bin/llvm-ml'), env), (tool.build(work), env)], calls
        assert out.getvalue() == (f'{work / tool.DLL}: SHA-256 {hashlib.sha256(b"built").hexdigest()}, not the pin '
                                  f'of tools/ue4ss.py ({ue4ss.DLL_SHA256})\n'), out.getvalue()
    finally:
        tool.subprocess, tool.shutil, xwin = saved
        if xwin is None:
            os.environ.pop('XWIN_DIR', None)
        else:
            os.environ['XWIN_DIR'] = xwin

print('ue4ss_build_test: ok')
