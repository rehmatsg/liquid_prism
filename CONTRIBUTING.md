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

Before packaging, run `flutter pub publish --dry-run` and inspect the file list.
Publishing to pub.dev is a separate maintainer action; CI does not publish.
`_research/` and `artifacts/` are local-only directories excluded from Git and
package archives. Keep required third-party notices and license texts in distributions.

An API or renderer change should be exercised on a real mobile renderer. Headless
widget tests use the fallback path and cannot certify shader output. Report device/build mode and remaining validation gaps.
