# Releases and packaging

## Automated releases (Release Please)

Liquid Prism uses [Release Please](https://github.com/googleapis/release-please) configured in `release-please-config.json`, `.release-please-manifest.json`, and `.github/workflows/release-please.yml`:

1. Merge PRs to `main` using Conventional Commits (`feat:`, `fix:`, `feat!:`, etc.).
2. Release Please maintains a release PR that bumps `pubspec.yaml`, `ios/liquid_prism.podspec`, `README.md`, `.release-please-manifest.json`, and `CHANGELOG.md`.
3. Merging the release PR tags `vX.Y.Z` and creates the GitHub Release automatically.

`tool/check_versions.py` (invoked by `tool/check.sh`) guarantees that `pubspec.yaml`, `ios/liquid_prism.podspec`, `.release-please-manifest.json`, and `README.md` never drift out of sync.

## Package archive verification

Run `flutter pub publish --dry-run` from the repository root. `.pubignore` excludes `research/`, `tool/`, `test/`, `.github/`, and generated build directories while packaging `lib/`, `ios/`, `shaders/`, licenses, and `THIRD_PARTY_NOTICES.md`.
