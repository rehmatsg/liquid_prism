import 'package:flutter/widgets.dart';

/// Chrome dock placement and sizing overrides for [PrismScaffold].
@immutable
class PrismScaffoldStyle {
  /// Creates a partial scaffold style override.
  const PrismScaffoldStyle({
    this.tabBarAlignment,
    this.tabBarMargin,
    this.tabBarMaxWidth,
    this.bottomBarAlignment,
    this.bottomBarMargin,
    this.bottomBarMaxWidth,
  }) : assert(tabBarMaxWidth == null || tabBarMaxWidth > 0),
       assert(bottomBarMaxWidth == null || bottomBarMaxWidth > 0);

  /// Cross-axis alignment within the tab bar dock.
  final AlignmentGeometry? tabBarAlignment;

  /// Margin surrounding the tab bar dock.
  final EdgeInsetsGeometry? tabBarMargin;

  /// Maximum width of the tab bar dock.
  final double? tabBarMaxWidth;

  /// Cross-axis alignment within the bottom bar dock.
  final AlignmentGeometry? bottomBarAlignment;

  /// Margin surrounding the bottom bar.
  final EdgeInsetsGeometry? bottomBarMargin;

  /// Maximum width of the bottom bar.
  final double? bottomBarMaxWidth;

  /// Returns a copy with specified fields replaced.
  PrismScaffoldStyle copyWith({
    AlignmentGeometry? tabBarAlignment,
    EdgeInsetsGeometry? tabBarMargin,
    double? tabBarMaxWidth,
    AlignmentGeometry? bottomBarAlignment,
    EdgeInsetsGeometry? bottomBarMargin,
    double? bottomBarMaxWidth,
  }) => PrismScaffoldStyle(
    tabBarAlignment: tabBarAlignment ?? this.tabBarAlignment,
    tabBarMargin: tabBarMargin ?? this.tabBarMargin,
    tabBarMaxWidth: tabBarMaxWidth ?? this.tabBarMaxWidth,
    bottomBarAlignment: bottomBarAlignment ?? this.bottomBarAlignment,
    bottomBarMargin: bottomBarMargin ?? this.bottomBarMargin,
    bottomBarMaxWidth: bottomBarMaxWidth ?? this.bottomBarMaxWidth,
  );

  /// Merges non-null fields from [other] over this style.
  PrismScaffoldStyle merge(PrismScaffoldStyle? other) => other == null
      ? this
      : PrismScaffoldStyle(
          tabBarAlignment: other.tabBarAlignment ?? tabBarAlignment,
          tabBarMargin: other.tabBarMargin ?? tabBarMargin,
          tabBarMaxWidth: other.tabBarMaxWidth ?? tabBarMaxWidth,
          bottomBarAlignment: other.bottomBarAlignment ?? bottomBarAlignment,
          bottomBarMargin: other.bottomBarMargin ?? bottomBarMargin,
          bottomBarMaxWidth: other.bottomBarMaxWidth ?? bottomBarMaxWidth,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismScaffoldStyle &&
          other.tabBarAlignment == tabBarAlignment &&
          other.tabBarMargin == tabBarMargin &&
          other.tabBarMaxWidth == tabBarMaxWidth &&
          other.bottomBarAlignment == bottomBarAlignment &&
          other.bottomBarMargin == bottomBarMargin &&
          other.bottomBarMaxWidth == bottomBarMaxWidth;

  @override
  int get hashCode => Object.hash(
    tabBarAlignment,
    tabBarMargin,
    tabBarMaxWidth,
    bottomBarAlignment,
    bottomBarMargin,
    bottomBarMaxWidth,
  );
}
