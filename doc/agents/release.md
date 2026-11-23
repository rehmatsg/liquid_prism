# Releases and packaging

## Releasing

`pubspec.yaml` holds the version. `ios/liquid_prism.podspec` and the install snippet in `README.md` mirror it, and `CHANGELOG.md` keeps one `## X.Y.Z` section per release with pending notes under `## Unreleased`.

1. Add notes under `## Unreleased` in `CHANGELOG.md` as changes merge.
2. In a release PR, run `python3 tool/release.py bump X.Y.Z`. It moves the pending notes under `## X.Y.Z` and updates the pubspec, podspec and README ref.
3. After that PR merges, tag the merge commit and push only the tag: `git tag vX.Y.Z && git push origin vX.Y.Z`.

Pushing the tag runs `.github/workflows/release.yml`:

- `verify` checks the tag against the pubspec, podspec, README and changelog (`tool/release.py check --tag`), then runs `tool/check.sh` and a publish dry run.
- `publish` uploads to pub.dev through OIDC. It runs only when the repository variable `PUBLISH_TO_PUB_DEV` is `true`, and needs automated publishing enabled on pub.dev with the tag pattern `v{{version}}`.
- `github-release` creates the GitHub release from that version's changelog section. A version with a `-` suffix is marked as a prerelease.
- `docs` deploys the API docs to GitHub Pages when the repository variable `DEPLOY_API_DOCS` is `true`, for full releases only.

`tool/check.sh` runs `tool/release.py check`, so version drift fails every PR.

## Package archive verification

Run `flutter pub publish --dry-run` from the repository root. `.pubignore` excludes `research/`, `tool/`, `test/`, `.github/`, and generated build directories while packaging `lib/`, `ios/`, `shaders/`, licenses, and `THIRD_PARTY_NOTICES.md`.
