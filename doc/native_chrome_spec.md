# Native toolbar and search reference

These measurements query UIView/CALayer bounds, transforms, font attributes,
resolved source colors and glassBackground inputs from standard SwiftUI
ToolbarItemGroup and searchable controls. The reference is iPhone 17,
iOS 27.0 (24A5370g), 402 × 874 points at 3×. Native UI tests passed in both
appearances, including focused and filled search states.

| Property | Captured value |
| --- | --- |
| Navigation toolbar capsule | 159 × 44 for star/share/ellipsis |
| Navigation visual item widths | 42⅓, 38⅔, 38 |
| Navigation outer inset / item gap | 4 / 16 |
| Bottom toolbar capsule | 100 × 48 for two chevrons; 48 × 48 for compose |
| Bottom visual item width / outer inset / gap | 38 / 5 / 14 |
| Navigation symbol image views (star / share / ellipsis) | 28⅓ × 27 / 24⅔ × 30 / 24 × 8⅓ |
| Bottom symbol image views (chevrons / compose) | 16 × 22⅔ / 26⅔ × 27 |
| Held capsule widths | 175, 116, 64 respectively |
| Held content | Whole group scales uniformly with the material |
| Search glass | 48 high; 346 wide at rest, 326 while focused |
| Search layout | Resting x=28; focused x=8; cancel x=346, width=48; gap=12 |
| Search bottom gap | 28 at rest; 10 above the keyboard (top y=539) |
| Search text | 17-point SFUI Regular; placeholder uses secondaryLabel |
| Search leading glyph / inset / text offset | 20⅓ × 19⅓ / 12 / 40⅓ |
| Filled search text area reduction | 36 |
| Clear glyph | 20 × 20, ending 13⅓ before the capsule edge |
| Glass blur / inner refraction | 5 / −half the capsule height |
| Inner refraction band | Quarter of the capsule height |

44-point and 48-point capsules use continuous corners. Toolbar source tint uses
systemBlueColor; text uses labelColor. The implementation resolves these from
GlassColors and uses the existing calibrated accent foreground. Placeholder and
disabled colors also come from the shared palette. Native backdrop-aware
vibrancy differs from painting a literal foreground color; that compositor and
CupertinoIcons glyphs remain approximations.

Item gaps refer to button bounds, not visible glyph edges. Native image views
enlarge their source symbols; using the source image size for a Flutter icon
made the visible gaps too wide. The default toolbar icon size is now 25.5 points,
bringing Cupertino glyph bounds closer to the rendered native symbols while
preserving the measured button centers, capsule widths and touch regions.
An explicit size on a caller-supplied icon still takes precedence.

Three held widths directly establish the 16-point width increase, including
the 48-point circle becoming 64 points wide. The whole shared material and its
contents lift together. Press/release springs reuse the package's fitted button
motion. Local item highlighting, focus/cancel transitions and private shadow
kernels are approximations. A search keyboard transition constructor reports
0.3833 seconds and an ease-in-out cubic; it does not establish the property
bindings of the private layout scheduler. The JSON preserves that evidence.

LiquidPrismToolbarGroup defaults to the bottom size; GlassToolbarSize.navigation
selects the compact size. GlassToolbarItem.width specifies the visual item
width; symbol-dependent native widths are supported explicitly. Action regions
also cover adjacent gaps. Groups scroll in narrow parents, support RTL, null
callbacks, keyboard/accessibility activation, and Reduce Motion.

LiquidPrismSearchField needs a bounded horizontal parent. Its caller may supply
a TextEditingController and FocusNode, which remain caller-owned. Search submits
through onSubmitted; Clear and Cancel notify onChanged when they clear text.
Cancel also releases focus and calls onCancel. Larger text increases the field's
height; very narrow fields hide the separate cancel action. These responsive
policies are adaptive fallbacks, not measured native configurations.

For the measured bottom layout, place the search widget inside an 8-point
horizontal inset and set restingInset=20. Screen placement and keyboard avoidance
belong to the containing layout; the field handles its own focus/clear/cancel
state. See example/lib/chrome_demo.dart for the complete arrangement.

Generate tool/native_chrome_probe with xcodegen and run its ChromeSpecs scheme on
the reference simulator. Copy app Documents/extracted and Documents/specs into
a raw directory as layers and specs. Run python3 tool/extract_chrome_spec.py
RAW_DIRECTORY from the repository root to regenerate the compact JSON. Raw
captures stay local; private introspection is confined to this development tool.
