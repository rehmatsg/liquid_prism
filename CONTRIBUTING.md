# Contributing to Liquid Prism

## Prerequisites

- **Flutter 3.50+** and **Dart 3.14+**
- macOS with Xcode for iOS builds and Swift unit tests

## Local Verification

Run the full check suite before opening a pull request:

```sh
./tool/check.sh
```

`tool/check.sh` verifies formatting, strict static analysis (`--fatal-infos`) for both the package and `example/`, Dart/Flutter tests, tooling tests, and version alignment.

For platform builds and Swift unit tests:

```sh
xcodebuild test -scheme liquid_prism-Package -destination 'platform=iOS Simulator,name=iPhone 17'
pod ipc spec ios/liquid_prism.podspec > /dev/null
cd example
flutter build ios --simulator --debug
flutter build apk --debug
```

Renderer or shader changes should also be exercised on a real Impeller simulator or device; headless widget tests exercise the frosted fallback and cannot certify shader output.

## Public API & Stability Policy

Starting with `1.0.0`, Liquid Prism follows [Semantic Versioning](https://semver.org):

- **Public entry points**:
  - `package:liquid_prism/liquid_prism.dart` — core consumer widgets, styles, theme, and native menus.
  - `package:liquid_prism/primitives.dart` — low-level optical, pressable, edge-blur, and system-chrome building blocks.
  - `lib/src/` is private implementation detail and not covered by SemVer guarantees.
- **Patch (`1.0.x`)**: bug fixes, performance improvements, and internal refactors with no breaking API changes.
- **Minor (`1.x.0`)**: backwards-compatible additions (new widgets, optional style fields, non-breaking behaviors).
- **Major (`2.0.0`)**: breaking API removals or signature changes. Deprecations are marked with `@Deprecated('... Will be removed in 2.0.0.')` for at least one minor release before removal.
- **Widget vs. style separation**: keep widget constructors focused on semantic and behavioral inputs; visual, geometry, optical, motion, and haptic overrides belong in immutable `Prism*Style` classes that implement `==`, `hashCode`, `copyWith`, and `merge`.

## Code Style

- Single quotes, sorted imports, strict typing (`strict-casts`, `strict-inference`, `strict-raw-types`), and zero analyzer infos.
- No inline `//` implementation comments. Keep concise one-line `///` dartdocs on public APIs only. Always preserve third-party license attribution headers.
- Format all Dart code with `dart format`.

## Commits & Releases

Pull request titles must follow [Conventional Commits](https://www.conventionalcommits.org):

- `feat:` / `feat(scope):` for a backwards-compatible feature
- `fix:` / `fix(scope):` for a bug fix
- `feat!:` or a `BREAKING CHANGE:` footer for a breaking change
- `perf:`, `refactor:`, `docs:`, `test:`, `ci:`, `build:`, `chore:`

Add a line for user-visible changes under `## Unreleased` in `CHANGELOG.md`.

Releases start from a version tag:
1. A release PR runs `python3 tool/release.py bump X.Y.Z`, which moves the pending changelog notes under the new version and updates `pubspec.yaml`, `ios/liquid_prism.podspec` and the README install ref.
2. A maintainer tags the merged commit and pushes the tag (`git tag vX.Y.Z && git push origin vX.Y.Z`).
3. The Release workflow verifies the versions, runs the checks, and creates the GitHub Release from the changelog section. See [doc/agents/release.md](doc/agents/release.md).
