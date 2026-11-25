#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""Builds the UE4SS.dll of SBO's UE4SS package on Linux: UE4SS-RE/RE-UE4SS tag v4.0.0 with PATCH, for Windows x64 in
the Game__Shipping__Win64 configuration of the official release.

It clones the tag with its submodules into <work>/src, checks that the tag is commit COMMIT, applies PATCH with git am
and checks that this gives commit PATCHED, then configures and builds the UE4SS target into <work>/build-rel with
clang-cl, lld-link and Ninja through the repository's xwin toolchain file. Cargo builds patternsleuth for
x86_64-pc-windows-msvc with CARGO_HOME in <work>/cargo-home. The compiler and Rust flags map the local folders to src,
build, cargo, rustup and xwin. /PDBALTPATH keeps the PDB's local path out of the DLL. /Brepro puts a hash of the DLL in
its PE header in place of the link time. No local path is written into the DLL as text. It prints the DLL's path and
SHA-256. tools/ue4ss.py packages the DLL only when that SHA-256 is its pin.

This build does not give the pinned DLL, so tools/ue4ss.py refuses its output. The pin was built by hand from commit
9a61a393, a commit of the same tree as PATCHED. The DLL holds the short hash of its commit: 4c8e4f4d from this tool,
9a61a393 in the pin. docs/dev/ue4ss.md names the other differences.

The proxy target (dwmapi.dll) is not built: its sources come from a Windows program that the build would run. No
Windows binary runs here. The package keeps the release's dwmapi.dll.

It needs git with a GitHub login that can read UE4SS-RE's private UEPseudo repository (deps/first/Unreal; gh's
credential helper serves the https URL), CMake, Ninja, LLVM (clang-cl, lld-link, llvm-ml), rustup's
x86_64-pc-windows-msvc target and the MSVC CRT and Windows SDK that xwin unpacks into XWIN_DIR (default
~/.local/share/xwin). The work folder must be missing or empty.

Run: python3 tools/ue4ss_build.py [<work folder>]   (default ~/.cache/sbo-ue4ss/ue4ss-build)"""
import email
import email.utils
import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # python3 -I leaves the script's folder out.
import ue4ss  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
URL = 'https://github.com/UE4SS-RE/RE-UE4SS.git'
TAG = 'v4.0.0'
COMMIT = '30afe5fff94a94c2313e220b2002059a080da9a0'  # Tag v4.0.0, the commit of the official release.
# COMMIT with PATCH, as am() and am_environment() make it on any PC: tree 874b6855. UE4SS's CMakeLists.txt compiles
# its short hash into the DLL (version info, log, window titles), so another commit gives another DLL.
PATCHED = '4c8e4f4dfe73e08a5dba821c2536f743f9d1ceaa'
PATCH = ROOT / ('ue4ss/patches/0001-fix-Lua-don-t-block-loading-threads-on-m_thread_actions_mutex-in-the-'
                'StaticConstructObject-hook.patch')
WORK = Path.home() / '.cache/sbo-ue4ss/ue4ss-build'
DLL = 'build-rel/Game__Shipping__Win64/bin/UE4SS.dll'  # Under the work folder.
JOBS = '6'
TOOLS = ('git', 'cmake', 'ninja', 'clang-cl', 'lld-link', 'llvm-ml', 'cargo')


def clone(src):
    """The clone of the tag with its submodules. deps/first/Unreal is listed with an SSH URL: the two insteadOf rules
    send it over https, where the GitHub login reads it."""
    return ['git', '-c', 'url.https://github.com/.insteadOf=git@github.com:',
            '-c', 'url.https://github.com/.insteadOf=ssh://git@github.com/',
            'clone', '--branch', TAG, '--recurse-submodules', '--shallow-submodules', URL, str(src)]


def check_commit(got, want=COMMIT, what=f'Tag {TAG}'):
    """Stops unless got is commit want. A moved tag would build other sources. Another patched commit gives another
    DLL."""
    if got.strip() != want:
        sys.exit(f'{what} is commit {got.strip()}, not {want}: refused. Nothing was built.')


def am(work):
    """git am of PATCH. The commit date is the author's date from the patch, not the time of the run."""
    return ['git', '-C', str(work / 'src'), 'am', '--committer-date-is-author-date', str(PATCH)]


def am_environment(env):
    """env for am(): the patch's author as committer and no user or system Git config, so the commit is PATCHED on any
    PC. commit.gpgsign=true would sign it, am.messageid=true would add a line to its message."""
    name, mail = email.utils.parseaddr(email.message_from_string(PATCH.read_text(encoding='utf-8'))['From'])
    return {**env, 'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_NOSYSTEM': '1',
            'GIT_COMMITTER_NAME': name, 'GIT_COMMITTER_EMAIL': mail}


def environment(work, env):
    """env with the build's variables. The flags go through CFLAGS, CXXFLAGS and LDFLAGS: the toolchain file adds
    its include flags to them, which -DCMAKE_CXX_FLAGS would replace."""
    src, build, cargo = work / 'src', work / 'build-rel', work / 'cargo-home'
    xwin = Path(env.get('XWIN_DIR', Path.home() / '.local/share/xwin'))
    rustup = Path(env.get('RUSTUP_HOME', Path.home() / '.rustup'))
    flags = ' '.join(f'/clang:-ffile-prefix-map={path}={name}' for path, name in ((src, 'src'), (build, 'build'),
                                                                                  (xwin, 'xwin')))
    return {**env, 'XWIN_DIR': str(xwin), 'CARGO_HOME': str(cargo),
            'CMAKE_BUILD_PARALLEL_LEVEL': JOBS, 'CARGO_BUILD_JOBS': JOBS,
            'RUSTFLAGS': f'--remap-path-prefix={src}=src --remap-path-prefix={cargo}=cargo '
                         f'--remap-path-prefix={rustup}=rustup',
            'CFLAGS': flags, 'CXXFLAGS': flags, 'LDFLAGS': '/PDBALTPATH:UE4SS.pdb /Brepro'}


def configure(work, llvm_ml):
    src = work / 'src'
    return ['cmake', '-S', str(src), '-B', str(work / 'build-rel'), '-G', 'Ninja',
            '-DCMAKE_BUILD_TYPE=Game__Shipping__Win64',
            f'-DCMAKE_TOOLCHAIN_FILE={src / "cmake/toolchains/xwin-clang-cl-toolchain.cmake"}',
            f'-DCMAKE_ASM_MASM_COMPILER:FILEPATH={llvm_ml}', '-DCMAKE_ASM_MASM_FLAGS:STRING=-m64']


def build(work):
    return ['cmake', '--build', str(work / 'build-rel'), '--target', 'UE4SS', f'-j{JOBS}']


def main(argv):
    if len(argv) > 2 or argv[1:2] in (['-h'], ['--help']):
        sys.exit(__doc__.rsplit('Run: ', 1)[1])
    work = Path(argv[1] if len(argv) == 2 else WORK).resolve()
    if ' ' in str(work):  # RUSTFLAGS, CFLAGS and CXXFLAGS split on spaces.
        sys.exit(f'{work} has a space in its path: pick another work folder.')
    if work.exists() and any(work.iterdir()):
        sys.exit(f'{work} is not empty: pick a new work folder or empty it first. Nothing was built.')
    if missing := [tool for tool in TOOLS if not shutil.which(tool)]:
        sys.exit(f'Missing on PATH: {", ".join(missing)}. Nothing was built.')
    env = environment(work, dict(os.environ))
    if not Path(env['XWIN_DIR']).is_dir():
        sys.exit(f'No xwin CRT and SDK at {env["XWIN_DIR"]} (set XWIN_DIR). Nothing was built.')
    work.mkdir(parents=True, exist_ok=True)
    subprocess.run(clone(work / 'src'), check=True)
    head = ['git', '-C', str(work / 'src'), 'rev-parse', 'HEAD']
    check_commit(subprocess.run(head, check=True, capture_output=True, text=True).stdout)
    subprocess.run(am(work), check=True, env=am_environment(dict(os.environ)))
    check_commit(subprocess.run(head, check=True, capture_output=True, text=True).stdout, PATCHED, 'The patched source')
    subprocess.run(configure(work, shutil.which('llvm-ml')), check=True, env=env)
    subprocess.run(build(work), check=True, env=env)
    dll = work / DLL
    got = hashlib.sha256(dll.read_bytes()).hexdigest()
    print(f'{dll}: SHA-256 {got}, ' + ('the pin of tools/ue4ss.py' if got == ue4ss.DLL_SHA256 else
                                       f'not the pin of tools/ue4ss.py ({ue4ss.DLL_SHA256})'))


if __name__ == '__main__':
    main(sys.argv)
