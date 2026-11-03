#!/usr/bin/env python3
"""tools/release.py with git, gh and tools/install.py faked: nothing runs and nothing leaves this machine.
Run: python3 tests/tools/release_test.py"""
import contextlib
import hashlib
import io
import json
import sys
import tempfile
import types
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import release  # noqa: E402

TAG = 'v0.8.0'
ZIP = f'StellarCoop-{TAG}.zip'
DATA = b'PK built zip, 25 bytes...'


class Fake:
    """git, gh and install.py. Every command is recorded; the GitHub release is a dict (None: no release)."""

    def __init__(self, tag=True, install_fails=False, draft=True, extra=b'', digest=lambda d: d, built=ZIP):
        self.tag, self.install_fails, self.extra, self.digest, self.built = tag, install_fails, extra, digest, built
        self.release = {'isDraft': draft, 'assets': []}
        if not draft:  # A published release has its zip.
            self.release['assets'] = [{'name': ZIP, 'size': len(DATA), 'state': 'uploaded',
                                       'digest': f'sha256:{hashlib.sha256(DATA).hexdigest()}'}]
        self.calls, self.install_cwd = [], None

    def run(self, args, cwd=None, **_):
        args = [str(arg) for arg in args]
        self.calls.append(args)
        code, out, err = 0, '', ''
        if args[:2] == ['git', 'rev-parse']:
            code = 0 if self.tag else 1
        elif args[:3] == ['git', 'worktree', 'add']:
            Path(args[4]).mkdir()
        elif args[1:] == ['tools/install.py', '--zip']:
            self.install_cwd = Path(cwd)
            if self.install_fails:
                code = 1
            else:
                (self.install_cwd / 'build').mkdir()
                (self.install_cwd / 'build' / self.built).write_bytes(DATA)
        elif args[:3] == ['gh', 'release', 'view']:
            if self.release is None:
                code, err = 1, 'release not found'
            else:
                out = json.dumps({field: self.release[field] for field in args[5].split(',')})
        elif args[:3] == ['gh', 'release', 'upload']:
            data = Path(args[4]).read_bytes() + self.extra
            self.release['assets'] = [{'name': Path(args[4]).name, 'size': len(data), 'state': 'uploaded',
                                       'digest': self.digest(f'sha256:{hashlib.sha256(data).hexdigest()}')}]
        elif args[:3] == ['gh', 'release', 'edit']:
            self.release['isDraft'] = False
        return types.SimpleNamespace(returncode=code, stdout=out, stderr=err)

    def kinds(self):
        """Each command in short: 'gh view <fields>', 'install', or the first three words."""
        return [f'gh view {c[5]}' if c[:3] == ['gh', 'release', 'view'] else 'install' if c[1:2] == ['tools/install.py']
                else ' '.join(c[:3]) for c in self.calls]


def run(fn, *args):
    """(exit code or sys.exit message, stdout + stderr) of fn(*args)."""
    out = io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
        try:
            code = fn(*args)
        except SystemExit as stop:
            code = stop.code
    return code, out.getvalue()


def fake(**kw):
    """Fresh fake commands put into the module."""
    commands = Fake(**kw)
    release.subprocess = types.SimpleNamespace(run=commands.run)
    return commands


with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    release.ROOT = tmp / 'repo'
    built = release.ROOT / 'build' / ZIP
    built.parent.mkdir(parents=True)

    # 1. Bad arguments stop before any command.
    commands = fake()
    for argv in (['main'], ['v0.8'], [TAG, '--zip', str(tmp / 'other.zip')], [TAG, '--only', 'build', '--zip', ZIP]):
        assert run(release.main, argv)[0] == 2, argv
    assert commands.calls == []

    # 2. A dry run prints the three steps in order and calls nothing, without a zip.
    code, out = run(release.main, [TAG, '--dry-run'])
    assert code is None and [line.split(':')[0] for line in out.splitlines()] == [
        'Dry run, build', 'Dry run, upload', 'Dry run, publish'], out
    assert commands.calls == []
    code, out = run(release.main, [TAG, '--dry-run', '--only', 'publish', 'upload', '--zip', str(built)])
    assert [line.split(':')[0] for line in out.splitlines()] == ['Dry run, upload', 'Dry run, publish'], out

    # 3. The build refuses a tag this clone does not have.
    commands = fake(tag=False)
    code, out = run(release.main, [TAG])
    assert code == f'No tag {TAG} in this clone: git fetch --tags first', code
    assert commands.kinds() == ['git rev-parse --verify']

    # 4. A failed install.py still removes the worktree, and the default flow stops there.
    commands = fake(install_fails=True)
    code, out = run(release.main, [TAG])
    assert code == f'tools/install.py --zip failed at {TAG}', code
    assert commands.kinds() == ['git rev-parse --verify', 'git worktree add', 'install', 'git worktree remove']
    assert not built.exists()

    # 5. An install.py that writes another zip name (git describe is not the tag) is refused, and nothing is copied.
    commands = fake(built='StellarCoop-v0.8.0-1-gabc1234.zip')
    code, out = run(release.main, [TAG])
    assert code == f'install.py wrote no build/{ZIP}: git describe is not {TAG}', code
    assert commands.kinds()[-1] == 'git worktree remove' and not built.exists()

    # 6. The whole flow: build at the tag, upload to the draft, check, then publish.
    commands = fake()
    code, out = run(release.main, [TAG])
    assert code is None, (code, out)
    assert commands.kinds() == ['git rev-parse --verify', 'git worktree add', 'install', 'git worktree remove',
                                'gh view isDraft', 'gh release upload', 'gh view assets', 'gh view assets',
                                'gh release edit']
    add, remove = commands.calls[1], commands.calls[3]
    assert add[3:] == ['--detach', str(commands.install_cwd), TAG] and remove[3:] == ['--force', add[4]]
    assert Path(tempfile.gettempdir()) in commands.install_cwd.parents and not commands.install_cwd.exists()
    assert commands.calls[5] == ['gh', 'release', 'upload', TAG, str(built), '--clobber', '-R', release.REPO]
    assert commands.calls[8] == ['gh', 'release', 'edit', TAG, '--draft=false', '-R', release.REPO]
    assert all(c[-2:] == ['-R', release.REPO] for c in commands.calls if c[0] == 'gh')
    assert built.read_bytes() == DATA

    # 7. Upload refusals: no release, a published release, then a size or a digest that differ (the flow stops before
    # publish). A gh without digests checks the size alone.
    for kw, start in (({}, 'gh release view'), ({'draft': False}, f'{TAG} is already published')):
        commands = fake(**kw)
        if not kw: commands.release = None
        code, out = run(release.main, [TAG, '--zip', str(built)])
        assert code.startswith(start) and 'gh release upload' not in commands.kinds(), code
    assert code.endswith(f'gh release edit {TAG} --draft=true -R {release.REPO}'), code
    for kw in ({'extra': b'!'}, {'digest': lambda d: 'sha256:' + '0' * 64}):
        commands = fake(**kw)
        code, out = run(release.main, [TAG, '--zip', str(built)])
        assert 'differs from' in code and commands.kinds()[-1] == 'gh view assets', code
        assert 'gh release edit' not in commands.kinds()
    commands = fake(digest=lambda d: None)
    assert run(release.main, [TAG, '--only', 'upload', '--zip', str(built)])[0] is None

    # 8. publish alone checks the asset first; a release without the zip stays a draft.
    commands = fake()
    code, out = run(release.main, [TAG, '--only', 'publish'])
    assert code == f'{TAG} has no asset {ZIP}' and commands.kinds() == ['gh view assets'], code
    code, out = run(release.main, [TAG, '--only', 'upload', 'publish'])
    assert code is None and commands.release['isDraft'] is False and commands.kinds()[-1] == 'gh release edit'
    missing = tmp / 'nowhere' / ZIP
    assert run(release.main, [TAG, '--only', 'upload', '--zip', str(missing)])[0] == (
        f'No {missing}: build it first (--only build) or pass --zip')

print('release_test: ok')
