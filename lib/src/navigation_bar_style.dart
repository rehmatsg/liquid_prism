import 'package:flutter/widgets.dart';

/// Navigation title typography and collapse.
///
/// Defaults are measured on iOS 27 (see doc/package_features_spec.md): a
/// 17-point semibold inline title centred on the 44-point control row, a
/// 34-point bold large title in a 52-point row 16 points from the edge, which
/// scrolls with the content and swaps to the inline title once the scroll
/// passes its row.
@immutable
class GlassNavigationBarStyle {
  const GlassNavigationBarStyle({
    this.titleStyle,
    this.largeTitleStyle,
    this.gutter,
    this.controlGap,
    this.revealExtent,
    this.revealCurve,
  }) : assert(gutter == null || gutter >= 0),
       assert(controlGap == null || controlGap >= 0),
       assert(revealExtent == null || revealExtent >= 0);
  final TextStyle? titleStyle, largeTitleStyle;
  final double? gutter, controlGap;

  /// Scroll distance at which the large title swaps for the inline title.
  /// Defaults to the large title's row height (52 points at default size);
  /// zero swaps on the first pixel.
  final double? revealExtent;

  /// Curve of the inline title's fade and 15-point rise as it appears
  /// (0.53 s; it leaves over 0.8 s on the flipped curve). Defaults to
  /// [Curves.easeOutCubic], fitted to the measured deceleration.
  final Curve? revealCurve;

  GlassNavigationBarStyle copyWith({
    TextStyle? titleStyle,
    TextStyle? largeTitleStyle,
    double? gutter,
    double? controlGap,
    double? revealExtent,
    Curve? revealCurve,
  }) => GlassNavigationBarStyle(
    titleStyle: titleStyle ?? this.titleStyle,
    largeTitleStyle: largeTitleStyle ?? this.largeTitleStyle,
    gutter: gutter ?? this.gutter,
    controlGap: controlGap ?? this.controlGap,
    revealExtent: revealExtent ?? this.revealExtent,
    revealCurve: revealCurve ?? this.revealCurve,
  );

  GlassNavigationBarStyle merge(GlassNavigationBarStyle? other) => other == null
      ? this
      : GlassNavigationBarStyle(
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          largeTitleStyle:
              largeTitleStyle?.merge(other.largeTitleStyle) ??
              other.largeTitleStyle,
          gutter: other.gutter ?? gutter,
          controlGap: other.controlGap ?? controlGap,
          revealExtent: other.revealExtent ?? revealExtent,
          revealCurve: other.revealCurve ?? revealCurve,
        );
}
