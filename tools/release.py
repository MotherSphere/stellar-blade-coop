#!/usr/bin/env python3
"""Finishes a release that Release Please created and the workflow holds as a draft. build: tools/install.py --zip in
a temporary worktree at the tag. upload: puts the zip on the draft release and checks the uploaded asset. publish:
checks the asset again, then publishes the release, which starts .github/workflows/nexus-upload.yml.
Run: python3 tools/release.py v0.8.0 [--only build upload publish] [--zip PATH] [--dry-run]"""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = 'MotherSphere/stellar-blade-coop'
STEPS = ('build', 'upload', 'publish')
PLANS = {
    'build': 'git worktree add --detach <temp dir> {tag}; python3 tools/install.py --zip there; copy its '
             'build/{name} to {zip}; git worktree remove --force <temp dir>',
    'upload': 'refuse unless {tag} is a draft release of {repo}; gh release upload {tag} {zip} --clobber; compare the '
              'asset size and SHA-256 with {zip}',
    'publish': 'compare the asset with {zip} again; gh release edit {tag} --draft=false',
}


def run(*args):
    """The command's stdout; a failure exits with its stderr."""
    done = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True, text=True)
    if done.returncode: sys.exit(f'{" ".join(map(str, args))} failed: {done.stderr.strip()}')
    return done.stdout


def release(tag, fields):
    return json.loads(run('gh', 'release', 'view', tag, '--json', fields, '-R', REPO))


def build(tag, zip_path):
    """The zip of the tag's commit, built in a temporary worktree so nothing uncommitted can get in."""
    if subprocess.run(['git', 'rev-parse', '--verify', '--quiet', f'refs/tags/{tag}'], cwd=ROOT,
                      capture_output=True).returncode:
        sys.exit(f'No tag {tag} in this clone: git fetch --tags first')
    with tempfile.TemporaryDirectory(prefix='stellarcoop-release-') as tmp:
        tree = Path(tmp) / 'tree'
        run('git', 'worktree', 'add', '--detach', tree, tag)
        try:
            if subprocess.run([sys.executable, 'tools/install.py', '--zip'], cwd=tree).returncode:
                sys.exit(f'tools/install.py --zip failed at {tag}')
            built = tree / 'build' / zip_path.name
            if not built.is_file(): sys.exit(f'install.py wrote no build/{zip_path.name}: git describe is not {tag}')
            zip_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(built, zip_path)
        finally:
            subprocess.run(['git', 'worktree', 'remove', '--force', str(tree)], cwd=ROOT)
    print(f'Built {zip_path}')


def check(tag, zip_path):
    """Exits unless the release's asset has the local zip's size and, when GitHub reports one, its SHA-256."""
    asset = next((a for a in release(tag, 'assets')['assets'] if a['name'] == zip_path.name), None)
    if not asset: sys.exit(f'{tag} has no asset {zip_path.name}')
    data = zip_path.read_bytes()
    digest = f'sha256:{hashlib.sha256(data).hexdigest()}'
    if asset['size'] != len(data) or asset.get('digest') not in (None, '', digest):
        sys.exit(f'{zip_path.name} on {tag} ({asset["size"]} bytes, {asset.get("digest")}) differs from {zip_path} '
                 f'({len(data)} bytes, {digest})')
    print(f'Checked {zip_path.name} on {tag}: {len(data)} bytes, {digest}')


def upload(tag, zip_path):
    if not release(tag, 'isDraft')['isDraft']:
        sys.exit(f'{tag} is already published, so its zip stays. To replace it, draft it first: '
                 f'gh release edit {tag} --draft=true -R {REPO}')
    run('gh', 'release', 'upload', tag, zip_path, '--clobber', '-R', REPO)
    check(tag, zip_path)


def publish(tag, zip_path):
    check(tag, zip_path)
    run('gh', 'release', 'edit', tag, '--draft=false', '-R', REPO)
    print(f'Published {tag}')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('tag', help='the release tag, such as v0.8.0')
    parser.add_argument('--only', nargs='+', choices=STEPS, metavar='STEP',
                        help=f'run only these steps, always in the order {" ".join(STEPS)} (default: all)')
    parser.add_argument('--zip', type=Path, help='an existing StellarCoop-<tag>.zip: skips the build')
    parser.add_argument('--dry-run', action='store_true', help='print what each step would do and call nothing')
    args = parser.parse_args(argv)
    tag = args.tag
    if not re.fullmatch(r'v\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?', tag): parser.error(f'{tag} is not a release tag')
    name = f'StellarCoop-{tag}.zip'
    zip_path = args.zip or ROOT / 'build' / name
    if zip_path.name != name: parser.error(f'--zip must be named {name}')
    steps = [s for s in STEPS if s in (args.only or STEPS) and not (args.zip and s == 'build')]
    if not steps: parser.error('--zip skips the build: nothing left to do')
    if args.dry_run:
        for step in steps:
            print(f'Dry run, {step}: ' + PLANS[step].format(tag=tag, name=name, zip=zip_path, repo=REPO))
        return
    if 'build' not in steps and not zip_path.is_file():
        sys.exit(f'No {zip_path}: build it first (--only build) or pass --zip')
    actions = {'build': lambda: build(tag, zip_path), 'upload': lambda: upload(tag, zip_path),
               'publish': lambda: publish(tag, zip_path)}
    for step in steps:
        actions[step]()


if __name__ == '__main__':
    main()
