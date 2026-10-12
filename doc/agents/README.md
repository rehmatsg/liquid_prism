# Agent documentation

Start with the repository's [AGENTS.md](../../AGENTS.md). This directory explains
implementation decisions and workflows; the [README](../../README.md) is for people
choosing and using the package.

| Task | Read |
| --- | --- |
| Understand the code | [Architecture](architecture.md) |
| Change a public API | [API contracts](api-design.md), [customization](../customization.md), [components](../components.md), [style reference](../style_reference.md) |
| Add or customize a component | [Implementation recipes](implementation-recipes.md) |
| Change motion or optics | [Rendering](rendering.md), [motion guide](../motion_and_lenses.md), [native comparison](native-comparison.md) |
| Verify behavior | [Testing](testing.md) |
| Build, install or package | [Delivery](release.md) |
| Diagnose an issue | [Troubleshooting](troubleshooting.md) |
| Change popup behavior | [Native menus](../native_menus.md), `lib/src/menu/`, `ios/Classes/` |

Use current source and tests as authority for API signatures. Specs distinguish
captured native values from fitted rendering behavior. Historical research can
explain a decision, but does not override the user's current instructions.

Do not read every guide for a small edit. Read architecture/API contracts, then
follow the relevant links. Keep these guides current when ownership, shader
packets, callback semantics or delivery commands change.
