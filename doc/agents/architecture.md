# Architecture

## Public boundary

Consumers import `package:liquid_prism/liquid_prism.dart`. It exports widgets,
materials, styles, motion, semantic colors and the merged menu API. The separate
`liquid_menu.dart` entry point supports menu-only consumers. Implementation files
under `lib/src/` are not a consumer contract.

| Files | Responsibility |
| --- | --- |
| `material.dart`, `style.dart` | Declarative glass variants, contours and optical packets |
| `appearance.dart`, `tab_bar_style.dart`, `theme.dart` | Partial component styles, inheritance and palette |
| `glass.dart`, `glass_group.dart`, `recipe.dart` | Surface composition, shader/fallback dispatch and explicit role IDs |
| `pressable.dart`, `motion.dart` | Button interaction and interruptible spring controllers |
| `control_interaction.dart`, `control_lens_motion.dart` | Controlled small-control input, cancellation and velocity deformation |
| `control_material.dart`, `control_lens.dart` | Track paint and shared resting/lifted lens with external shadows |
| `switch.dart`, `slider.dart`, `segmented_control.dart` | Per-component layout, logical value mapping and native defaults |
| `tab_bar.dart`, `tab_content_lens.dart` | Compact navigation layout, independent tab motion and foreground filter |
| `toolbar.dart`, `chrome_material.dart`, `search_field.dart` | Grouped action layout and owned/borrowed search resources |
| `menu/`, `ios/Classes/` | Menu models, platform interface, fallback and UIKit presentation |
| `shaders/` | Impeller glass, batched surfaces and tab glyph refraction |

## Ownership

Widgets own geometry; interaction wrappers own pointer/key/semantics input and
animation. Values remain parent-owned. A native menu trigger owns a single
activation path and delegates popup presentation to the platform bridge.

The search field disposes only controllers/focus nodes it created. Caller-owned
objects may be replaced during rebuild; listeners must move to the new objects.
Keep borrowed objects alive and preserve editor value when switching to an owned
controller. Controller mutation does not imply `onChanged`, as with Flutter editors.

Themes merge nullable fields. Component styles resolve before building internal
materials. Native geometry and palette are fallbacks, not eagerly filled style
fields: filling them early would defeat inheritance.

## Rendering order

A surface samples already-painted background. A lifted lens samples the track or
housing beneath it. External shadows paint after lens capture so their clipped
masks cannot appear as an extra shape inside the glass. Slider track minification
is off by default even though its knob enlarges.

Tab foreground is special: draw ordinary content outside the selection and filter
a separately tinted pass inside its contour. It has independent sampling bounds,
DPR and SDF depth. Housing minification cannot substitute for glyph refraction.
See [rendering](rendering.md) before altering this path.

## Reference and consumer apps

`example/lib/main.dart` runs the showcase. `example/lib/api_main.dart` is a small
customization example. Controls/chrome entry points isolate measurements.
`example/test_driver/` contains simulator interaction/recording fixtures.
`tool/native_showcase/` is the SwiftUI reference; other `tool/native_*` projects
measure native properties. Inspection hooks stay in probes, never in the plugin.
The package does not depend on local captures under `_research/` or `artifacts/`.
