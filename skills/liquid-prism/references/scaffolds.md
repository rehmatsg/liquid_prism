# Scaffolds and scroll edges

Check these contracts against the app's resolved package source. This guide
covers the 0.7 scaffold API; newer title behavior may require a newer release,
and the pull to refresh described below needs 0.8 (0.9 for its controller,
failure result and haptics hook).

## Select the composition

| Need | Composition and ownership |
| --- | --- |
| An ordinary scrolling page | `LiquidPrismScaffold(slivers: ...)` owns the scroll view, chrome insets and scroll notifications. |
| A custom body or tabbed/nested scroll views | `body:` owns its scroll views and consumes the scaffold's supplied `MediaQuery.padding`. Choose `scrollDepth` for the vertical scrollable driving chrome. |
| An app-owned sliver scroll view and app bar | `LiquidPrismSliverAppBar` owns that bar. Avoid also creating a scaffold top bar for the same region. |
| A permanent row below the title | `accessory: PreferredSize(...)` participates in scaffold chrome geometry and its shared scroll edge. Its height must describe the row. |
| Content that scrolls and then pins | A pinned sliver in managed `slivers`. Its content lifecycle differs from an accessory; any custom background effect needs explicit coordination. |

Supply exactly one of `body` and `slivers`. `header` requires managed slivers.
A custom `header` and `largeTitle` are alternatives.

A minimal managed page (inside a Flutter app):

```dart
LiquidPrismScaffold(
  title: const Text('Library'),
  largeTitle: const Text('Library'),
  slivers: [
    SliverList.builder(
      itemCount: 30,
      itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
    ),
  ],
)
```

Do not add a second top/bottom safe-area padding around managed slivers. With
`body`, a `ListView`/`GridView` without explicit padding consumes the supplied
padding automatically. Explicit padding replaces that behavior; a custom scroll
view must apply the supplied insets itself, from a context **inside** the body.
Do not apply the same insets through both `SafeArea` and scroll padding.

`scrollDepth` counts nested scrollables: zero for the outer one, one for a
vertical list inside a page view. Verify the actual notification depth rather
than increasing it until a title happens to animate. Preserve the appropriate
primary/controller relationship for scroll-to-top and tab reselection.

## Pull to refresh

From 0.8, `onRefresh: () => reload()` on the scaffold is the whole integration,
for `slivers` and for `body`. The scaffold draws a black drop out of the Dynamic
Island, a notch or the top edge, arms it at a fixed pull, and holds a spinner
until the returned future completes. Before 0.8 `onRefresh` required `slivers`
and showed the stock Cupertino control; check the resolved version.

- Return the future of the real reload. The indicator spins until it completes,
  and for at least a moment so a fast reload still reads. Do not add your own
  delay, loading flag or spinner for the same reload.
- Do not add `RefreshIndicator`, `CupertinoSliverRefreshControl` or another
  refresh package inside a scaffold that has `onRefresh`; two indicators would
  answer the same pull.
- The drop follows the scrollable at `scrollDepth`. With `body`, a list shorter
  than the window needs `AlwaysScrollableScrollPhysics` to be pulled at all.
- The content is not held down while refreshing, so do not reserve space for
  the indicator. There is no style to configure: it is always black and its
  anchor comes from the device.
- A scaffold in a sheet draws the drop from the sheet's own top edge.

From 0.9:

- To refresh from code (a tab tapped again, a deep link), pass a
  `LiquidPrismRefreshController` as `refreshController` and call `refresh()`.
  Do not fake a pull by scrolling, and do not show a separate spinner.
- A page that only sometimes allows refresh passes `onRefresh: allowed ?
  reload : null`. This keeps scroll position and focus; do not pass a no-op
  callback to work around a rebuild.
- When the app records failures instead of throwing, return them: a future
  that completes with `false` ends without the check or success haptic.
- Refresh haptics go through the theme's `GlassHaptics` hook
  (`GlassHapticComponent.refresh`). Route them through the app's own haptics
  setting there rather than calling `HapticFeedback` beside the scaffold. An
  exhaustive `switch` over `GlassHapticKind` or `GlassHapticComponent` in app
  code needs the new cases.

## Adaptive safe areas

Let automatic placement follow system chrome and window changes. Screen width,
a device name, or a portrait/landscape test is not a substitute for reserved
regions and safe areas. Actions can occupy a side rail independently of the
scrolling title. Do not move them with an app-owned title transform.

The body receives safe insets **plus measured chrome coverage** through
`MediaQuery.padding`. `LiquidPrismScaffold.contentInsetsOf(context)` instead
returns content-safe insets including a rail; it is useful for overlays outside
the body, such as aligning a route's drag indicator with its title. It does not
return app-bar/accessory heights or the entire body padding. Its optional
`placement` is for an overlay associated with a different chrome placement.

Do not use `topBarClearance` as universal spacing between arbitrary widgets.
For example, 0.7.2 uses 10 logical pixels in regular chrome and 16 for rail
content spacing, before overrides. Those numbers explain why fixed stitching
fails; they are not values to copy into an app. Check resolved geometry instead.

Keyboard avoidance defaults to folding the keyboard into body padding. If the
app disables it, descendants own avoidance; do not compensate in both places.

## Title and accessory lifecycle

Use `title` for the compact title and `largeTitle` for the expanded title. Use
`header` for arbitrary content that scrolls away before the compact title appears.
A custom header uses its measured extent; do not assume a large-title reveal
threshold controls it. Keep interactive titles in the title slot, with a single
accessible activation owner, rather than moving them to `leading` for tap support.

`GlassNavigationBarStyle` controls alignment and minimization. Exercise pinned,
scroll-away and reveal-on-scroll-up with an accessory present: the accessory
remains usable when the title row hides. Expanded titles, compact titles and
custom headers have different motion roles. Do not wrap all of them in the same
fade/blur/size animation or recreate a title subtree with a new key every frame.

## Continuous scroll edges

Prefer the scaffold's one effect across its title and accessory. A separately
pinned content row is not automatically part of that effect. Before adding a
`LiquidPrismScrollEdge` to it, establish:

- Where both effects begin and end in the same coordinate space, including their
  extension beyond layout bounds and any clipping.
- Whether the profile has a full-strength plateau or starts fading immediately.
  Equal `sigma` and color do not imply equal appearance: `falloff`, `extension`,
  haze and opacity also matter.
- Which scroll offset drives each effect. A pinned header's `shrinkOffset` is
  not necessarily the scaffold's scroll progress.
- Whether overlap compounds blur/opacity, or a gap exposes untreated content.

Truncating the app-bar effect with a fixed extension and starting an independent
row effect at assumed padding can produce both a seam and mismatched frosting.
Do not hide that defect by increasing global glass opacity. If the desired
scroll-then-pin composition needs coordination the public API does not provide,
report the limitation or propose a package change instead of importing internals.

Bottom chrome uses a soft edge, or no effect when disabled; do not introduce a
hard bottom edge. For custom rounded routes, inspect both the presented surface
and the transformed underlying page's effect bounds. `sheet: true` configures
bar layout; it is not a sheet route or a guarantee of route clipping. Liquid
Prism does not provide a sheet, wheel-picker or date-picker component.
