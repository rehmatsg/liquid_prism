import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/navigation/prism_system_chrome.dart';

/// System-adaptive bottom or side-rail chrome placement.
enum PrismChromePlacement {
  /// Places chrome along the bottom edge.
  bottom,

  /// Places chrome in a left side rail.
  leftRail,

  /// Places chrome in a right side rail.
  rightRail;

  /// Whether chrome occupies a vertical side rail.
  bool get isRail => this != bottom;

  /// Resolves rail placement from asymmetric safe-area insets.
  static PrismChromePlacement resolve(
    EdgeInsets viewPadding, {
    double railInset = 48,
  }) {
    final difference = viewPadding.right - viewPadding.left;
    if (difference >= railInset) return rightRail;
    if (-difference >= railInset) return leftRail;
    return bottom;
  }
}

@internal
PrismChromePlacement prismSystemChromePlacement(
  EdgeInsets padding,
  PrismSystemChromeData? system,
) => switch (system) {
  null => PrismChromePlacement.resolve(padding),
  PrismSystemChromeData(hasVerticalBar: false) => PrismChromePlacement.bottom,
  PrismSystemChromeData(verticalBarEdge: AxisDirection.left) =>
    PrismChromePlacement.leftRail,
  _ => PrismChromePlacement.rightRail,
};

@internal
Rect? prismTopChromeCorner(Size size, Iterable<Rect> occlusions) {
  for (final region in occlusions) {
    final touchesTop = region.top <= 1;
    final corner = region.left <= 1 || (size.width - region.right).abs() <= 1;
    if (touchesTop && corner && region.width < size.width / 2) {
      return region;
    }
  }
  return null;
}

@internal
@immutable
class PrismChrome extends InheritedWidget {
  const new({
    super.key,
    required this.placement,
    required super.child,
    this.axis,
  });

  final PrismChromePlacement placement;

  final Axis? axis;

  static PrismChrome? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrismChrome>();

  @override
  bool updateShouldNotify(PrismChrome oldWidget) =>
      placement != oldWidget.placement || axis != oldWidget.axis;
}
