part of 'toolbar.dart';

/// Scaffold regions for toolbar content. Standalone toolbars use list order.
enum GlassToolbarPlacement {
  automatic,
  topLeading,
  topTrailing,
  principal,
  bottomLeading,
  bottom,
  bottomTrailing,
}

/// Which bar axes an item may sit in, as SwiftUI's `ToolbarItemAxisBehavior`.
///
/// Where the system lays bars out vertically (the iPhone Duo's side rail),
/// items that suit a fixed width and flexible height move into the vertical
/// bar and the rest stay in a horizontal one: top items in the top bar and
/// bottom items along the content's bottom edge.
enum GlassToolbarAxisBehavior {
  /// An item with an icon may sit in a vertical bar; a text-only item or a
  /// custom widget stays horizontal.
  automatic,

  /// Always horizontal: for an item whose label changes between a symbol and
  /// text, such as Edit and Done, which would otherwise jump between axes.
  horizontalOnly,

  /// Prefers the vertical bar when there is one: for a custom widget that has
  /// a good vertical form.
  verticalPreferred,
}

@immutable
sealed class GlassToolbarContent {
  const GlassToolbarContent({
    this.key,
    this.placement = GlassToolbarPlacement.automatic,
  });
  final Key? key;
  final GlassToolbarPlacement placement;
}

/// An action, native menu, or app-owned widget. An omitted icon draws the label.
final class GlassToolbarItem extends GlassToolbarContent {
  const GlassToolbarItem({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
    super.placement,
    this.selected = false,
    this.foregroundColor,
    this.badge,
    this.width,
    this.axisBehavior = GlassToolbarAxisBehavior.automatic,
  }) : menu = null,
       onMenuSelected = null,
       _menuEnabled = false,
       child = null,
       assert(width == null || width >= 36);

  const GlassToolbarItem.menu({
    required this.label,
    required LiquidMenu this.menu,
    this.icon,
    ValueChanged<Object?>? onSelected,
    bool enabled = true,
    super.key,
    super.placement,
    this.selected = false,
    this.foregroundColor,
    this.badge,
    this.width,
    this.axisBehavior = GlassToolbarAxisBehavior.automatic,
  }) : onPressed = null,
       onMenuSelected = onSelected,
       _menuEnabled = enabled,
       child = null,
       assert(width == null || width >= 36);

  /// Keeps the child's own gestures and semantics. Outside a group it has no
  /// added glass; inside an explicit group it shares that group's capsule.
  const GlassToolbarItem.custom({
    required Widget this.child,
    this.width,
    super.key,
    super.placement,
    this.axisBehavior = GlassToolbarAxisBehavior.automatic,
  }) : label = '',
       icon = null,
       onPressed = null,
       menu = null,
       onMenuSelected = null,
       _menuEnabled = false,
       selected = false,
       foregroundColor = null,
       badge = null,
       assert(width == null || width >= 0);

  final Widget? icon, child;
  final String label;
  final FutureOr<void> Function()? onPressed;
  final bool selected;
  final Color? foregroundColor;
  final GlassBadge? badge;
  final LiquidMenu? menu;
  final ValueChanged<Object?>? onMenuSelected;
  final bool _menuEnabled;
  bool get _isEnabled => menu == null ? onPressed != null : _menuEnabled;

  /// Main-axis extent. Icons default to 38 (or a circle when alone), text is
  /// measured, and grouped custom content defaults to the control's extent.
  /// Ungrouped custom content can instead use its intrinsic size.
  final double? width;

  /// Which bar axes the item may sit in when the scaffold lays bars out
  /// vertically.
  final GlassToolbarAxisBehavior axisBehavior;
}

/// Items that share one capsule, including an empty group that may appear later.
final class GlassToolbarGroup extends GlassToolbarContent {
  const GlassToolbarGroup({
    required this.items,
    this.style,
    super.key,
    super.placement,
  });
  final List<GlassToolbarItem> items;
  final GlassToolbarStyle? style;
}

/// A break between capsules. Flexible space requires a bounded main axis.
final class GlassToolbarSpacer extends GlassToolbarContent {
  const GlassToolbarSpacer.fixed(
    double this.extent, {
    super.key,
    super.placement,
  }) : flex = 1,
       assert(extent >= 0);
  const GlassToolbarSpacer.flexible({this.flex = 1, super.key, super.placement})
    : extent = null,
      assert(flex > 0);
  final double? extent;
  final int flex;
}

List<GlassToolbarContent> glassToolbarSegments(
  List<GlassToolbarContent> content,
) {
  final result = <GlassToolbarContent>[];
  List<GlassToolbarItem>? loose;
  for (final entry in content) {
    if (entry is GlassToolbarItem && entry.child == null) {
      if (loose == null) {
        loose = [];
        result.add(GlassToolbarGroup(items: loose));
      }
      loose.add(entry);
    } else {
      loose = null;
      result.add(entry);
    }
  }
  return result;
}

List<GlassToolbarContent> glassToolbarAt(
  List<GlassToolbarContent> content,
  GlassToolbarPlacement placement,
) => [
  for (final entry in content)
    if (entry.placement == placement ||
        (placement == GlassToolbarPlacement.topTrailing &&
            entry.placement == GlassToolbarPlacement.automatic))
      entry,
];

TextStyle glassToolbarTextStyle(GlassToolbarStyle style) => const TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
).merge(style.textStyle);

double glassToolbarItemExtent(
  BuildContext context,
  GlassToolbarItem item,
  GlassToolbarStyle style, {
  bool lone = false,
  double height = 48,
  double inset = 5,
  bool vertical = false,
}) {
  if (item.width != null) return item.width!;
  if (item.icon != null || item.child != null || vertical) {
    return lone ? math.max(height - inset * 2, 0) : 38;
  }
  final painter = TextPainter(
    text: TextSpan(text: item.label, style: glassToolbarTextStyle(style)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = math.max(38.0, painter.width + 16);
  painter.dispose();
  return width;
}

/// Whether [entry] may sit in a vertical bar. A group goes vertical only when
/// every item in it can, so related items keep one axis; an empty group keeps
/// its place in the vertical bar, where it may later fill.
bool glassToolbarIsVertical(GlassToolbarContent entry) => switch (entry) {
  GlassToolbarItem(:final axisBehavior) => switch (axisBehavior) {
    GlassToolbarAxisBehavior.horizontalOnly => false,
    GlassToolbarAxisBehavior.verticalPreferred => true,
    GlassToolbarAxisBehavior.automatic =>
      entry.icon != null && entry.child == null,
  },
  GlassToolbarGroup(:final items) => items.every(glassToolbarIsVertical),
  GlassToolbarSpacer() => true,
};

/// Splits [content] between a vertical bar and the horizontal bar beside it.
///
/// Items keep their order on both sides. Spacers go with the vertical side,
/// where a flexible spacer collapses to nothing, as natively; the horizontal
/// side here is the few items a vertical layout leaves behind, so it takes no
/// spacing of its own.
({List<GlassToolbarContent> vertical, List<GlassToolbarContent> horizontal})
glassToolbarSplitByAxis(List<GlassToolbarContent> content) {
  final vertical = <GlassToolbarContent>[];
  final horizontal = <GlassToolbarContent>[];
  for (final entry in content) {
    if (entry is GlassToolbarSpacer) {
      if (entry.extent != null) vertical.add(entry);
    } else if (glassToolbarIsVertical(entry)) {
      vertical.add(entry);
    } else {
      horizontal.add(entry);
    }
  }
  return (vertical: vertical, horizontal: horizontal);
}

List<GlassToolbarContent> glassBottomToolbarContent(
  List<GlassToolbarContent> content,
) {
  final leading = glassToolbarAt(content, GlassToolbarPlacement.bottomLeading);
  final center = glassToolbarAt(content, GlassToolbarPlacement.bottom);
  final trailing = glassToolbarAt(
    content,
    GlassToolbarPlacement.bottomTrailing,
  );
  if (leading.isEmpty && center.isEmpty && trailing.isEmpty) return const [];
  return [
    ...leading,
    if (center.isNotEmpty || trailing.isNotEmpty)
      const GlassToolbarSpacer.flexible(),
    ...center,
    if (center.isNotEmpty || leading.isNotEmpty)
      const GlassToolbarSpacer.flexible(),
    ...trailing,
  ];
}

bool glassToolbarHasContent(List<GlassToolbarContent> content) => content.any(
  (entry) => switch (entry) {
    GlassToolbarGroup(:final items) => items.isNotEmpty,
    GlassToolbarItem() => true,
    GlassToolbarSpacer() => false,
  },
);

GlassToolbarStyle glassToolbarStyleFor(
  BuildContext context,
  GlassToolbarSize size,
) => GlassToolbarStyle(size: size).merge(LiquidPrismTheme.of(context).toolbar);
