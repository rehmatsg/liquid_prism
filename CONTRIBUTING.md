# Contributing

Use Flutter 3.47+ with Dart 3.13.3+. iOS builds require macOS and a compatible Xcode.
The public API is exported by `lib/liquid_prism.dart`; keep consumer examples and
`doc/` in sync when changing it.

```sh
flutter pub get
./tool/check.sh
cd example
flutter build ios --simulator --debug
flutter build apk --debug
```

The check script formats nothing: it reports formatting differences, runs analysis,
and executes package and example tests. CI bounds each job. For tests, prefer
observable behavior through the public API: gestures, semantics, color overrides,
inheritance, disposal, and fallback behavior.

## Versions and releases

Versions follow [semantic versioning](https://semver.org) with Dart's rule
before 1.0: a minor bump (0.2 → 0.3) marks breaking changes, a patch bump marks
fixes and compatible additions. `pubspec.yaml` holds the version; the podspec
mirrors it, and `tool/check.sh` fails if they or `CHANGELOG.md` disagree.

Add a line under `## Unreleased` in `CHANGELOG.md` with each user-visible
change. To release:

1. On a branch, run `python3 tool/release.py bump X.Y.Z`. It moves the
   Unreleased notes under `## X.Y.Z` and sets both versions. Merge it through
   a pull request.
2. Tag the merge commit on `main` and push the tag:
   `git tag -a vX.Y.Z -m "Liquid Prism X.Y.Z" && git push origin vX.Y.Z`.
3. The Release workflow checks the tag against the versions, runs the checks
   and publishes a GitHub release with that version's notes. A version with a
   suffix, such as `0.3.0-beta.1`, becomes a pre-release.

The package is not published to pub.dev; apps depend on a release tag through
Git. CI still runs `flutter pub publish --dry-run` to keep the package valid.
`_research/` and `artifacts/` are local-only directories excluded from Git and
package archives. Keep required third-party notices and license texts in distributions.

An API or renderer change should be exercised on a real mobile renderer. Headless
widget tests use the fallback path and cannot certify shader output. Report device/build mode and remaining validation gaps.

Read [AGENTS.md](AGENTS.md) and the [implementation guides](doc/agents/README.md)
for ownership rules, API precedence, shader ABI and native comparison workflows.
The [API example](example/lib/api_main.dart) should remain runnable using only
public exports. Keep README usage concise; put implementation detail in the guides.
