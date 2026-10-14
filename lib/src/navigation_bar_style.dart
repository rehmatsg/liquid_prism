import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';

import 'motion.dart' show GlassSpring;

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
    this.subtitleStyle,
    this.largeSubtitleStyle,
    this.gutter,
    this.controlGap,
    this.revealExtent,
    @Deprecated('The swap now runs on a spring; use revealSpring.')
    this.revealCurve,
    this.revealSpring,
  }) : assert(gutter == null || gutter >= 0),
       assert(controlGap == null || controlGap >= 0),
       assert(revealExtent == null || revealExtent >= 0);
  final TextStyle? titleStyle, largeTitleStyle;

  /// The subtitle under the inline title (12-point regular secondary label)
  /// and under the large title (11-point medium secondary label), measured.
  final TextStyle? subtitleStyle, largeSubtitleStyle;
  final double? gutter, controlGap;

  /// Scroll distance at which the large title swaps for the inline title.
  /// Defaults to the large title's row height (52 points at default size);
  /// zero swaps on the first pixel.
  final double? revealExtent;

  /// Curve of the inline title's fade and 15-point rise as it appears
  /// (0.53 s; it leaves over 0.8 s on the flipped curve). Defaults to
  /// [Curves.easeOutCubic], fitted to the measured deceleration.
  @Deprecated('The swap now runs on a spring; use revealSpring.')
  final Curve? revealCurve;

  /// The inline title's spring as it fades and rises 15 points into place,
  /// and back out. Defaults to [titleSpring].
  final GlassSpring? revealSpring;

  /// Fitted to the measured rise: settles in about half a second with a
  /// little bounce.
  static const titleSpring = GlassSpring(
    response: Duration(milliseconds: 500),
    bounce: .2,
  );

  /// The large title's quick fade, about 0.18 s, without bounce.
  static const largeTitleSpring = GlassSpring(
    response: Duration(milliseconds: 180),
    bounce: 0,
  );

  GlassNavigationBarStyle copyWith({
    TextStyle? titleStyle,
    TextStyle? largeTitleStyle,
    TextStyle? subtitleStyle,
    TextStyle? largeSubtitleStyle,
    double? gutter,
    double? controlGap,
    double? revealExtent,
    Curve? revealCurve,
    GlassSpring? revealSpring,
  }) => GlassNavigationBarStyle(
    titleStyle: titleStyle ?? this.titleStyle,
    largeTitleStyle: largeTitleStyle ?? this.largeTitleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    largeSubtitleStyle: largeSubtitleStyle ?? this.largeSubtitleStyle,
    gutter: gutter ?? this.gutter,
    controlGap: controlGap ?? this.controlGap,
    revealExtent: revealExtent ?? this.revealExtent,
    // ignore: deprecated_member_use_from_same_package
    revealCurve: revealCurve ?? this.revealCurve,
    revealSpring: revealSpring ?? this.revealSpring,
  );

  GlassNavigationBarStyle merge(GlassNavigationBarStyle? other) => other == null
      ? this
      : GlassNavigationBarStyle(
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          largeTitleStyle:
              largeTitleStyle?.merge(other.largeTitleStyle) ??
              other.largeTitleStyle,
          subtitleStyle:
              subtitleStyle?.merge(other.subtitleStyle) ?? other.subtitleStyle,
          largeSubtitleStyle:
              largeSubtitleStyle?.merge(other.largeSubtitleStyle) ??
              other.largeSubtitleStyle,
          gutter: other.gutter ?? gutter,
          controlGap: other.controlGap ?? controlGap,
          revealExtent: other.revealExtent ?? revealExtent,
          // ignore: deprecated_member_use_from_same_package
          revealCurve: other.revealCurve ?? revealCurve,
          revealSpring: other.revealSpring ?? revealSpring,
        );
}

/// A title with an optional subtitle line below it: centred under the inline
/// title; under the large one, [subtitleOffset] below the title's top (38.33
/// points for a 34-point title, measured on iOS 27), whatever the font's line
/// height.
@internal
Widget glassTitled(
  Widget title,
  Widget? subtitle,
  TextStyle subtitleStyle, {
  required bool large,
  bool leading = false,
  double subtitleOffset = 0,
}) {
  if (subtitle == null) return title;
  final line = DefaultTextStyle(
    style: subtitleStyle,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    child: subtitle,
  );
  if (!large) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: leading
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [title, line],
    );
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: subtitleOffset,
        child: OverflowBox(
          alignment: AlignmentDirectional.topStart,
          maxHeight: double.infinity,
          child: title,
        ),
      ),
      line,
    ],
  );
}
