#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
dart format --output=none --set-exit-if-changed lib test example/lib example/test
flutter analyze
flutter test --timeout=30s
(cd example && flutter test --timeout=30s)
python3 -m unittest discover -s test/tooling -p 'test_*.py'
python3 tool/release.py check > /dev/null
