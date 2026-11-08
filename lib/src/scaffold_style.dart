import 'package:flutter/widgets.dart';

/// Placement within the safe content area. Null fields retain native defaults.
@immutable
class GlassScaffoldStyle {
  const GlassScaffoldStyle({
    this.tabBarAlignment,
    this.tabBarMargin,
    this.tabBarMaxWidth,
    this.bottomBarAlignment,
    this.bottomBarMargin,
    this.bottomBarMaxWidth,
  }) : assert(tabBarMaxWidth == null || tabBarMaxWidth > 0),
       assert(bottomBarMaxWidth == null || bottomBarMaxWidth > 0);

  /// Cross-axis alignment within the chosen tab dock; defaults to center.
  final AlignmentGeometry? tabBarAlignment;

  /// Replaces the dock's native gap. The scaffold already accounts for side
  /// and top safe areas; bottom defaults preserve the native floating gap.
  final EdgeInsetsGeometry? tabBarMargin;

  /// Maximum horizontal tab width, or vertical dock width. Defaults to 440.
  final double? tabBarMaxWidth;
  final AlignmentGeometry? bottomBarAlignment;

  /// Insets above the keyboard, tab dock or native bottom gap.
  final EdgeInsetsGeometry? bottomBarMargin;
  final double? bottomBarMaxWidth;

  GlassScaffoldStyle copyWith({
    AlignmentGeometry? tabBarAlignment,
    EdgeInsetsGeometry? tabBarMargin,
    double? tabBarMaxWidth,
    AlignmentGeometry? bottomBarAlignment,
    EdgeInsetsGeometry? bottomBarMargin,
    double? bottomBarMaxWidth,
  }) => GlassScaffoldStyle(
    tabBarAlignment: tabBarAlignment ?? this.tabBarAlignment,
    tabBarMargin: tabBarMargin ?? this.tabBarMargin,
    tabBarMaxWidth: tabBarMaxWidth ?? this.tabBarMaxWidth,
    bottomBarAlignment: bottomBarAlignment ?? this.bottomBarAlignment,
    bottomBarMargin: bottomBarMargin ?? this.bottomBarMargin,
    bottomBarMaxWidth: bottomBarMaxWidth ?? this.bottomBarMaxWidth,
  );

  GlassScaffoldStyle merge(GlassScaffoldStyle? other) => other == null
      ? this
      : GlassScaffoldStyle(
          tabBarAlignment: other.tabBarAlignment ?? tabBarAlignment,
          tabBarMargin: other.tabBarMargin ?? tabBarMargin,
          tabBarMaxWidth: other.tabBarMaxWidth ?? tabBarMaxWidth,
          bottomBarAlignment: other.bottomBarAlignment ?? bottomBarAlignment,
          bottomBarMargin: other.bottomBarMargin ?? bottomBarMargin,
          bottomBarMaxWidth: other.bottomBarMaxWidth ?? bottomBarMaxWidth,
        );
}
