#!/usr/bin/env python3
"""Verify that package versions agree across pubspec, podspec, manifest, and README."""

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SEMVER = r'\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?'
PUBSPEC_VERSION = re.compile(rf'^version:\s*({SEMVER})\s*$', re.M)
PODSPEC_VERSION = re.compile(rf"^\s*s\.version\s*=\s*'({SEMVER})'", re.M)
README_REF = re.compile(rf'^\s*ref:\s*v({SEMVER})\b', re.M)


class VersionError(Exception):
    pass


def check(root: Path = ROOT) -> str:
    pubspec = (root / 'pubspec.yaml').read_text()
    match = PUBSPEC_VERSION.search(pubspec)
    if not match:
        raise VersionError('pubspec.yaml has no semantic version')
    version = match.group(1)

    podspec = (root / 'ios/liquid_prism.podspec').read_text()
    pod_match = PODSPEC_VERSION.search(podspec)
    if not pod_match or pod_match.group(1) != version:
        found = pod_match.group(1) if pod_match else 'none'
        raise VersionError(f'podspec version {found} != pubspec {version}')

    manifest_path = root / '.release-please-manifest.json'
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        if manifest.get('.') != version:
            raise VersionError(
                f'.release-please-manifest.json version {manifest.get(".")} != pubspec {version}'
            )

    readme_path = root / 'README.md'
    if readme_path.exists():
        readme_match = README_REF.search(readme_path.read_text())
        if readme_match and readme_match.group(1) != version:
            raise VersionError(
                f'README.md ref v{readme_match.group(1)} != v{version}'
            )

    return version


def main(root: Path = ROOT) -> int:
    try:
        print(check(root))
    except VersionError as error:
        print(f'version check failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
