# Working on Liquid Prism

Liquid Prism is a Flutter package and an iOS native-menu plugin. Keep public APIs
simple by default and deeply configurable through immutable styles. Preserve the
captured native defaults when adding customization.

## Read first

1. [Agent documentation index](doc/agents/README.md): choose the guides for your task.
2. [Architecture](doc/agents/architecture.md) and [API contracts](doc/agents/api-design.md).
3. The relevant component source, tests and native spec in `doc/`.

Use `lib/liquid_prism.dart` as the consumer entry point. `lib/liquid_menu.dart`
remains available for menu-only consumers. `lib/src/` is implementation detail.

## Product constraints

- Keep native iOS popups native: use the merged Liquid Menu bridge. Do not recreate
  iOS popup surfaces, typography or animations in Flutter.
- Sheets, wheel pickers and date pickers were explicitly removed. Do not reintroduce
  them unless the user requests them again.
- Keep compact tab sizing as the default. Full width is explicit opt-in.
- Keep shared lifted-lens styling and size-relative shadows. Slider knobs still
  grow on hold, but their underlying track does not minify by default.
- Preserve motion-driven deformation, switch haptics, the switch's 220 ms minimum
  tap lift, and the continuous slider fill blend across the first/last 2%.
- Preserve tab foreground refraction independently from housing minification.

## Implementation rules

- Prefer additive, typed APIs. Existing constructors and callback semantics must
  keep working unless a requested migration explicitly changes them.
- Resolve defaults in this order: direct widget argument, local component style,
  component theme, native fallback. Merge nullable style fields individually.
  Respect explicit false/zero. Optical packets replace as a whole.
- Keep parent-owned values authoritative. Preserve cancellation, rejected updates,
  RTL, semantics, controller ownership and Reduce Motion.
- Use the shared palette and continuous contours. Avoid unrelated visual retuning.
- Shader role IDs are explicit ABI values; never replace them with enum indices.
  Update both Dart uniforms and GLSL when changing a shader packet.
- Do not add another gesture owner around a button, menu trigger or control.
- Never ship private UIKit inspection hooks. Reference probes belong under `tool/`.
- Do not infer exact native algorithms from screenshots or constructor arguments.
  Record direct measurements separately from fitted renderer behavior.

## Verify

Run `tool/check.sh` after implementation. Add tests for meaningful behavior or API
contracts; avoid tests that only repeat assignments. Exercise renderer/API changes
in the showcase on a real Impeller simulator or device. Headless widget tests
exercise the fallback and cannot prove shader output.

After Dart changes, hot reload/restart the running app. After GLSL or shader asset
changes, stop and rebuild it; hot restart alone can retain an old shader program.
Use [testing](doc/agents/testing.md) and [native comparison](doc/agents/native-comparison.md)
for commands. Verify snippets and public exports alongside code changes.

Keep the README short and written for people. Put implementation details and agent
instructions in `doc/agents/`. Update component/customization docs when APIs change.

## Collaboration and delivery

Respect the user's current scope and existing authorization. Continue reversible
work without unnecessary confirmation. Preserve unrelated changes. Do not create
new chats or send messages to other tasks without the user's authorization.

Report what changed, what passed, and any actual validation gap. Never claim an
app was installed, a build launched, or a commit pushed until tools confirm it.
Do not commit generated builds, recordings, private captures, provisioning data
or credentials. `_research/` and `artifacts/` are local evidence, not required
sources for consumers. Preserve all redistribution notices.
