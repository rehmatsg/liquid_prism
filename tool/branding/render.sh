#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"
mkdir -p artifacts/branding/.build
swiftc -O "$repo_root/tool/branding/render_wordmark.swift" -o artifacts/branding/.build/render_wordmark
exec artifacts/branding/.build/render_wordmark "$@"
