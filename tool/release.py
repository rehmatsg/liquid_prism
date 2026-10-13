#!/usr/bin/env python3
"""Keep the package version in one place and prepare releases.

  release.py check [--tag vX.Y.Z]  pubspec, podspec and changelog agree
  release.py bump X.Y.Z            move Unreleased notes under X.Y.Z
  release.py notes X.Y.Z           print that version's changelog notes

pubspec.yaml holds the version. The podspec mirrors it, and CHANGELOG.md keeps
an `## Unreleased` section above one `## X.Y.Z` section per release.
"""
import argparse
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SEMVER = r'\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?'
PUBSPEC_VERSION = re.compile(rf'^version:\s*({SEMVER})\s*$', re.M)
PODSPEC_VERSION = re.compile(rf"^(\s*s\.version\s*=\s*)'({SEMVER})'", re.M)
HEADING = re.compile(r'^## (.+?)\s*$', re.M)


class ReleaseError(Exception):
    pass


def files(root):
    return (root / 'pubspec.yaml', root / 'ios/liquid_prism.podspec',
            root / 'CHANGELOG.md')


def version_of(root):
    pubspec, _, _ = files(root)
    match = PUBSPEC_VERSION.search(pubspec.read_text())
    if not match:
        raise ReleaseError('pubspec.yaml has no semantic version')
    return match.group(1)


def sections(changelog):
    """Changelog headings in order, each with its body."""
    text = changelog.read_text()
    marks = list(HEADING.finditer(text))
    return [(m.group(1), text[m.end():marks[i + 1].start() if i + 1 < len(marks)
                              else len(text)].strip())
            for i, m in enumerate(marks)]


def check(root, tag=None):
    version = version_of(root)
    _, podspec, changelog = files(root)
    match = PODSPEC_VERSION.search(podspec.read_text())
    if not match or match.group(2) != version:
        found = match.group(2) if match else 'none'
        raise ReleaseError(f'podspec version {found} != pubspec {version}')
    headings = [name for name, _ in sections(changelog)]
    if version not in headings:
        raise ReleaseError(f'CHANGELOG.md has no "## {version}" section')
    if tag is not None and tag != f'v{version}':
        raise ReleaseError(f'tag {tag} != v{version} from pubspec.yaml')
    return version


def key(version):
    core, _, pre = version.partition('-')
    # A pre-release sorts before its release.
    return tuple(int(n) for n in core.split('.')), pre == '', pre


def bump(root, version):
    if not re.fullmatch(SEMVER, version):
        raise ReleaseError(f'{version} is not a semantic version')
    current = check(root)
    if key(version) <= key(current):
        raise ReleaseError(f'{version} is not after {current}')
    pubspec, podspec, changelog = files(root)
    notes = dict(sections(changelog)).get('Unreleased')
    if not notes:
        raise ReleaseError('CHANGELOG.md has no notes under "## Unreleased"')
    changelog.write_text(changelog.read_text().replace(
        '## Unreleased', f'## Unreleased\n\n## {version}', 1))
    pubspec.write_text(PUBSPEC_VERSION.sub(
        f'version: {version}', pubspec.read_text(), count=1))
    podspec.write_text(PODSPEC_VERSION.sub(
        rf"\g<1>'{version}'", podspec.read_text(), count=1))
    return check(root)


def notes(root, version):
    body = dict(sections(files(root)[2])).get(version)
    if body is None:
        raise ReleaseError(f'CHANGELOG.md has no "## {version}" section')
    return body


def main(argv=None, root=ROOT):
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('check').add_argument('--tag')
    commands.add_parser('bump').add_argument('version')
    commands.add_parser('notes').add_argument('version')
    args = parser.parse_args(argv)
    try:
        if args.command == 'check':
            print(check(root, args.tag))
        elif args.command == 'bump':
            print(bump(root, args.version))
        else:
            print(notes(root, args.version))
    except ReleaseError as error:
        print(f'release: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
