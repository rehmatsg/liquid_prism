---
name: liquid-prism
description: Integrate, customize, migrate, or diagnose Liquid Prism components in Flutter apps, including adaptive scaffolds, app bars, pull to refresh, pinned rows, scroll edges, glass controls, and native menus.
---

# Liquid Prism integration

Use Liquid Prism's public composition APIs and preserve native defaults unless
an app explicitly chooses a different treatment. This skill is for consuming
apps; it does not authorize package releases or unrelated app migrations.

## Establish the installed contract

Read the app's dependency declaration, lockfile and
`.dart_tool/package_config.json` to locate the resolved `liquid_prism` version
and source. Check that version's public exports, constructor documentation and
relevant examples before using an API. A checkout or online main branch may be
newer than the app's dependency. Do not edit the package cache.

Import `package:liquid_prism/liquid_prism.dart`, or `liquid_menu.dart` for
menu-only use. Internal source can explain behavior but is not an app API.

## Choose ownership before styling

For screen layout, app bars, tabs, safe areas, pull to refresh or scroll seams, read
[Scaffolds and scroll edges](references/scaffolds.md). Identify which widget
owns scrolling, content insets, chrome and its background effect before adding
padding or another blur. Prefer managed scaffold slivers for ordinary scrolling
pages. Distinguish a permanent chrome accessory from content that scrolls before
pinning; they are not interchangeable.

For controls, materials, titles or menus, read
[Components and defaults](references/components.md). Prefer omitted defaults,
small local overrides and reusable immutable styles over copying native values
into app code. Preserve the component's own activation and animation ownership.

## Diagnose and verify the affected behavior

Trace the widget tree and resolved settings before attributing a visual defect
to the shader. Record the scroll offset, appearance, glass setting, window safe
areas and chrome placement needed to reproduce it. For a seam, compare effect
bounds, fade profiles and progress sources, not just blur sigma.

Choose checks from [Integration verification](references/verification.md) that
exercise the changed behavior. Widget tests can establish geometry and input
contracts; they cannot establish Impeller glass output. Report observed results
and remaining visual validation gaps separately. Respect a diagnosis-only task;
do not silently turn it into implementation.
