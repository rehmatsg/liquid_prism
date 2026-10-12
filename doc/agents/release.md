# Delivery and packaging

## Before committing

Run [checks](testing.md), inspect `git diff --check`, review `git diff --stat` and
verify only task-owned files are staged. Preserve upstream license notices.
Update public guides for API changes. Do not include build products, captures,
provisioning, signing secrets or local research in the commit.

Respect the current user's commit/push authorization. Verify the actual branch,
remote and push result. Publishing to pub.dev, deployment and messages to others
are separate actions; do not infer those from a request to improve the library.

## Build matrix

```sh
cd example
flutter build ios --simulator --debug
flutter build apk --debug
# Physical iPhone:
flutter build ios --release
```

Use the configured Xcode installation and existing signing settings. Do not
invent a new bundle ID/team to bypass a provisioning issue. Native showcase builds
use the project/scheme under `tool/native_showcase/`; list schemes first. Its
release app and Flutter release app are distinct products.

## Physical iPhone

```sh
xcrun devicectl list devices
xcrun devicectl device install app --device <device-id> <absolute-app-path>
xcrun devicectl device process launch --device <device-id> <bundle-id> --terminate-existing
```

Confirm the connected device and install result. If the phone is unavailable,
finish independent verification and explain the concrete blocker. Existing user
permission to install persists across turns. Do not claim a simulator launch was
an iPhone install. Do not commit device identifiers or signing credentials to docs.

## Package archive

Run `flutter pub publish --dry-run` from the repository root. Inspect its file
list and warnings. `.pubignore` excludes tooling, tests, local artifacts and
platform-generated example directories. Public docs and agent guides are small
text sources and may ship in the archive. The package is not published yet;
README installation currently uses Git.

No runtime code may depend on `_research/`, `artifacts/` or a local probe. Native
popup bridge code and shader assets must be packaged. Keep the BSD and merged
Liquid Menu MIT notices available to consumers.
