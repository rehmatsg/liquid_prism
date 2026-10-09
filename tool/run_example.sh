#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../example"
if [[ $# -gt 0 ]]; then
  exec flutter run --debug --target lib/main.dart -d "$1"
fi
exec flutter run --debug --target lib/main.dart
