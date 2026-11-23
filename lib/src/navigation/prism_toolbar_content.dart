import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/prism_badge.dart';
import '../menu/menu.dart';
import '../theme/prism_theme.dart';
import 'prism_toolbar_style.dart';

/// Scaffold region occupied by toolbar content.
enum PrismToolbarPlacement {
  automatic,
  topLeading,
  topTrailing,
  principal,
  bottomLeading,
  bottom,
  bottomTrailing,
}

/// Axes a toolbar item supports when system chrome becomes a rail.
enum PrismToolbarAxisBehavior { automatic, horizontalOnly, verticalPreferred }

/// Typed content placed in a toolbar or scaffold region.
@immutable
sealed class PrismToolbarContent {
  /// Creates content with an optional identity and scaffold placement.
  const PrismToolbarContent({
    this.key,
    this.placement = PrismToolbarPlacement.automatic,
  });

  /// Identity used to preserve content across updates.
  final Key? key;

  /// Scaffold region that receives this content.
  final PrismToolbarPlacement placement;
}

/// An action, native menu, or custom widget in a toolbar.
final class PrismToolbarItem extends PrismToolbarContent {
  /// Creates a toolbar action.
  const PrismToolbarItem({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
    super.placement,
    this.selected = false,
    this.foregroundColor,
    this.badge,
    this.width,
    this.axisBehavior = PrismToolbarAxisBehavior.automatic,
  }) : menu = null,
       onMenuSelected = null,
       _menuEnabled = false,
       child = null,
       assert(width == null || width >= 36);

  /// Creates a toolbar item that owns native menu activation.
  const PrismToolbarItem.menu({
    required this.label,
    required PrismMenu this.menu,
    this.icon,
    ValueChanged<Object?>? onSelected,
    bool enabled = true,
    super.key,
    super.placement,
    this.selected = false,
    this.foregroundColor,
    this.badge,
    this.width,
    this.axisBehavior = PrismToolbarAxisBehavior.automatic,
  }) : onPressed = null,
       onMenuSelected = onSelected,
       _menuEnabled = enabled,
       child = null,
       assert(width == null || width >= 36);

  /// Uses the custom widget's own gestures and semantics.
  const PrismToolbarItem.custom({
    required Widget this.child,
    this.width,
    super.key,
    super.placement,
    this.axisBehavior = PrismToolbarAxisBehavior.automatic,
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

  /// Optional action icon; an omitted icon displays the label.
  final Widget? icon;

  /// Custom content that retains its own gestures and semantics.
  final Widget? child;

  /// Accessible label, also displayed when an icon is omitted.
  final String label;

  /// Activation callback; null disables the action.
  final FutureOr<void> Function()? onPressed;

  /// Whether this action reports selected semantics.
  final bool selected;

  /// Optional foreground color for this item.
  final Color? foregroundColor;

  /// Optional status or count badge.
  final PrismBadge? badge;

  /// Native menu presented when this item is activated.
  final PrismMenu? menu;

  /// Callback receiving the selected native menu value.
  final ValueChanged<Object?>? onMenuSelected;
  final bool _menuEnabled;
  @internal
  bool get isEnabled => menu == null ? onPressed != null : _menuEnabled;

  /// Main-axis extent; null uses the native item measurement.
  final double? width;

  /// Axes this item supports in adaptive system chrome.
  final PrismToolbarAxisBehavior axisBehavior;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismToolbarItem &&
          other.key == key &&
          other.placement == placement &&
          other.icon == icon &&
          other.child == child &&
          other.label == label &&
          other.onPressed == onPressed &&
          other.selected == selected &&
          other.foregroundColor == foregroundColor &&
          other.badge == badge &&
          other.menu == menu &&
          other.onMenuSelected == onMenuSelected &&
          other._menuEnabled == _menuEnabled &&
          other.width == width &&
          other.axisBehavior == axisBehavior;

  @override
  int get hashCode => Object.hashAll([
    key,
    placement,
    icon,
    child,
    label,
    onPressed,
    selected,
    foregroundColor,
    badge,
    menu,
    onMenuSelected,
    _menuEnabled,
    width,
    axisBehavior,
  ]);
}

/// Ordered items sharing one animated glass capsule.
final class PrismToolbarGroup extends PrismToolbarContent {
  /// Creates a capsule content group, including an initially empty group.
  const PrismToolbarGroup({
    required this.items,
    this.style,
    super.key,
    super.placement,
  });

  /// Ordered items sharing the capsule.
  final List<PrismToolbarItem> items;

  /// Local appearance overrides merged over the component theme.
  final PrismToolbarStyle? style;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismToolbarGroup &&
          other.key == key &&
          other.placement == placement &&
          listEquals(other.items, items) &&
          other.style == style;

  @override
  int get hashCode =>
      Object.hashAll([key, placement, Object.hashAll(items), style]);
}

/// Fixed or flexible space between toolbar capsules.
final class PrismToolbarSpacer extends PrismToolbarContent {
  /// Creates a fixed break between capsules.
  const PrismToolbarSpacer.fixed(
    double this.extent, {
    super.key,
    super.placement,
  }) : flex = 1,
       assert(extent >= 0);

  /// Creates flexible space on a bounded main axis.
  const PrismToolbarSpacer.flexible({this.flex = 1, super.key, super.placement})
    : extent = null,
      assert(flex > 0);

  /// Fixed spacer extent, or null for flexible space.
  final double? extent;

  /// Flexible spacer weight.
  final int flex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismToolbarSpacer &&
          other.key == key &&
          other.placement == placement &&
          other.extent == extent &&
          other.flex == flex;

  @override
  int get hashCode => Object.hashAll([key, placement, extent, flex]);
}

@internal
List<PrismToolbarContent> prismToolbarSegments(
  List<PrismToolbarContent> content,
) {
  final result = <PrismToolbarContent>[];
  List<PrismToolbarItem>? loose;
  for (final entry in content) {
    if (entry is PrismToolbarItem && entry.child == null) {
      if (loose == null) {
        loose = [];
        result.add(PrismToolbarGroup(items: loose));
      }
      loose.add(entry);
    } else {
      loose = null;
      result.add(entry);
    }
  }
  return result;
}

@internal
List<PrismToolbarContent> prismToolbarAt(
  List<PrismToolbarContent> content,
  PrismToolbarPlacement placement,
) => [
  for (final entry in content)
    if (entry.placement == placement ||
        (placement == PrismToolbarPlacement.topTrailing &&
            entry.placement == PrismToolbarPlacement.automatic))
      entry,
];

@internal
TextStyle prismToolbarTextStyle(PrismToolbarStyle style) => const TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
).merge(style.textStyle);

@internal
double prismToolbarItemExtent(
  BuildContext context,
  PrismToolbarItem item,
  PrismToolbarStyle style, {
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
    text: TextSpan(text: item.label, style: prismToolbarTextStyle(style)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = math.max(38.0, painter.width + 16);
  painter.dispose();
  return width;
}

@internal
bool prismToolbarIsVertical(PrismToolbarContent entry) => switch (entry) {
  PrismToolbarItem(:final axisBehavior) => switch (axisBehavior) {
    PrismToolbarAxisBehavior.horizontalOnly => false,
    PrismToolbarAxisBehavior.verticalPreferred => true,
    PrismToolbarAxisBehavior.automatic =>
      entry.icon != null && entry.child == null,
  },
  PrismToolbarGroup(:final items) => items.every(prismToolbarIsVertical),
  PrismToolbarSpacer() => true,
};

@internal
({List<PrismToolbarContent> vertical, List<PrismToolbarContent> horizontal})
prismToolbarSplitByAxis(List<PrismToolbarContent> content) {
  final vertical = <PrismToolbarContent>[];
  final horizontal = <PrismToolbarContent>[];
  for (final entry in content) {
    if (entry is PrismToolbarSpacer) {
      if (entry.extent != null) vertical.add(entry);
    } else if (prismToolbarIsVertical(entry)) {
      vertical.add(entry);
    } else {
      horizontal.add(entry);
    }
  }
  return (vertical: vertical, horizontal: horizontal);
}

@internal
List<PrismToolbarContent> prismBottomToolbarContent(
  List<PrismToolbarContent> content,
) {
  final leading = prismToolbarAt(content, PrismToolbarPlacement.bottomLeading);
  final center = prismToolbarAt(content, PrismToolbarPlacement.bottom);
  final trailing = prismToolbarAt(
    content,
    PrismToolbarPlacement.bottomTrailing,
  );
  if (leading.isEmpty && center.isEmpty && trailing.isEmpty) return const [];
  return [
    ...leading,
    if (center.isNotEmpty || trailing.isNotEmpty)
      const PrismToolbarSpacer.flexible(),
    ...center,
    if (center.isNotEmpty || leading.isNotEmpty)
      const PrismToolbarSpacer.flexible(),
    ...trailing,
  ];
}

@internal
int prismToolbarItemCount(List<PrismToolbarContent> content) => content.fold(
  0,
  (count, entry) =>
      count +
      switch (entry) {
        PrismToolbarGroup(:final items) => items.length,
        PrismToolbarItem() => 1,
        PrismToolbarSpacer() => 0,
      },
);

@internal
bool prismToolbarHasContent(List<PrismToolbarContent> content) => content.any(
  (entry) => switch (entry) {
    PrismToolbarGroup(:final items) => items.isNotEmpty,
    PrismToolbarItem() => true,
    PrismToolbarSpacer() => false,
  },
);

@internal
PrismToolbarStyle prismToolbarStyleFor(
  BuildContext context,
  PrismToolbarSize size,
) => PrismToolbarStyle(size: size).merge(PrismTheme.of(context).toolbar);
