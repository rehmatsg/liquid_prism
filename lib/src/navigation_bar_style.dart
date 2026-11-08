import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart' show GlassSpring;
import 'title.dart' show GlassTitleStyle;

enum GlassTitleAlignment { automatic, leading, center, trailing }

enum GlassToolbarMinimizationBehavior {
  automatic,
  never,
  onScrollDown,
  onScrollUp,
}

enum GlassToolbarMinimizationRestoration { automatic, atScrollEdge }

enum GlassToolbarMinimizationSafeAreaAdjustment { automatic, enabled, disabled }

/// Navigation title typography, layout and collapse.
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
    this.titleAlignment,
    this.largeTitleAlignment,
    this.minimizationBehavior,
    this.minimizationThreshold,
    this.minimizationRestoration,
    this.minimizationSafeAreaAdjustment,
    this.controlRowHeight,
    this.contentPadding,
    this.largeTitleExtent,
    this.largeTitleStyle,
    this.subtitleStyle,
    this.largeSubtitleStyle,
    this.gutter,
    this.controlGap,
    this.contentSpacing,
    this.revealExtent,
    this.revealSpring,
    this.hideSpring,
    this.inlineTitleDelay,
    this.largeTitleFadeDuration,
    this.largeTitleFadeCurve,
    this.titleCapsule,
  }) : assert(gutter == null || gutter >= 0),
       assert(controlGap == null || controlGap >= 0),
       assert(contentSpacing == null || contentSpacing >= 0),
       assert(revealExtent == null || revealExtent >= 0),
       assert(controlRowHeight == null || controlRowHeight >= 44),
       assert(largeTitleExtent == null || largeTitleExtent >= 0),
       assert(minimizationThreshold == null || minimizationThreshold >= 0);
  final TextStyle? titleStyle, largeTitleStyle;

  /// The subtitle under the inline title (12-point regular secondary label)
  /// and under the large title (11-point medium secondary label), measured.
  final TextStyle? subtitleStyle, largeSubtitleStyle;
  final double? gutter, controlGap;

  /// Clearance below navigation chrome: 10 pt for standard top bars,
  /// 16 pt for rail/sidebar layouts.
  final double? contentSpacing;
  final GlassTitleAlignment? titleAlignment;

  /// Expanded title alignment. Automatic retains the native leading edge.
  final GlassTitleAlignment? largeTitleAlignment;

  /// Automatic retains the captured non-minimizing default.
  final GlassToolbarMinimizationBehavior? minimizationBehavior;

  /// Initial scroll distance before minimization starts; fitted default 13⅓ pt.
  final double? minimizationThreshold;

  /// Automatic restores on scroll reversal. At-scroll-edge restoration applies
  /// to on-scroll-down minimization and waits until the content reaches its top.
  final GlassToolbarMinimizationRestoration? minimizationRestoration;

  /// Automatic adjusts body safe-area insets as the bar minimizes. Disabled
  /// keeps them fixed for content drawn beneath the chrome.
  final GlassToolbarMinimizationSafeAreaAdjustment?
  minimizationSafeAreaAdjustment;

  /// Minimum height of the controls, before text scaling. Defaults to 44.
  final double? controlRowHeight;

  /// Additional insets inside the safe area; directional values follow RTL.
  final EdgeInsetsGeometry? contentPadding;

  /// Expanded title row height. Null measures typography at the current scale.
  final double? largeTitleExtent;

  /// Scroll distance at which the large title swaps for the inline title.
  /// Defaults to the large title's row height (52 points at default size);
  /// zero swaps on the first pixel.
  final double? revealExtent;

  /// The inline title's spring as it fades and rises 15 points into place.
  /// Defaults to [titleSpring]; [hideSpring] controls the outgoing motion.
  final GlassSpring? revealSpring;

  /// The inline title's outgoing spring, independent of its reveal.
  final GlassSpring? hideSpring;

  /// Fitted onset lag behind the large-title fade, 12 ms. Applied only when
  /// starting at rest; reversals retain continuous motion.
  final Duration? inlineTitleDelay;

  /// The large title's opacity animation. Native UIKit records 200 ms with
  /// the ease-in-out Bezier; see doc/navigation_bar_spec.json.
  final Duration? largeTitleFadeDuration;
  final Curve? largeTitleFadeCurve;

  /// Geometry and glass of `LiquidPrismTitle` capsules in these bars; a
  /// title's own style wins per field.
  final GlassTitleStyle? titleCapsule;

  /// Fitted to native opacity and the correlated 15-point rise, with separate
  /// reveal/hide profiles. These are renderer fits, not recovered algorithms.
  static const titleSpring = GlassSpring.physical(
    SpringDescription(mass: 1, stiffness: 225, damping: 28.3),
  );
  static const titleHideSpring = GlassSpring.physical(
    SpringDescription(mass: 1, stiffness: 93.3, damping: 18.22),
  );

  GlassNavigationBarStyle copyWith({
    TextStyle? titleStyle,
    GlassTitleAlignment? titleAlignment,
    GlassTitleAlignment? largeTitleAlignment,
    GlassToolbarMinimizationBehavior? minimizationBehavior,
    double? minimizationThreshold,
    GlassToolbarMinimizationRestoration? minimizationRestoration,
    GlassToolbarMinimizationSafeAreaAdjustment? minimizationSafeAreaAdjustment,
    double? controlRowHeight,
    EdgeInsetsGeometry? contentPadding,
    double? largeTitleExtent,
    TextStyle? largeTitleStyle,
    TextStyle? subtitleStyle,
    TextStyle? largeSubtitleStyle,
    double? gutter,
    double? controlGap,
    double? contentSpacing,
    double? revealExtent,
    GlassSpring? revealSpring,
    GlassSpring? hideSpring,
    Duration? inlineTitleDelay,
    Duration? largeTitleFadeDuration,
    Curve? largeTitleFadeCurve,
    GlassTitleStyle? titleCapsule,
  }) => GlassNavigationBarStyle(
    titleStyle: titleStyle ?? this.titleStyle,
    titleAlignment: titleAlignment ?? this.titleAlignment,
    largeTitleAlignment: largeTitleAlignment ?? this.largeTitleAlignment,
    minimizationBehavior: minimizationBehavior ?? this.minimizationBehavior,
    minimizationThreshold: minimizationThreshold ?? this.minimizationThreshold,
    minimizationRestoration:
        minimizationRestoration ?? this.minimizationRestoration,
    minimizationSafeAreaAdjustment:
        minimizationSafeAreaAdjustment ?? this.minimizationSafeAreaAdjustment,
    controlRowHeight: controlRowHeight ?? this.controlRowHeight,
    contentPadding: contentPadding ?? this.contentPadding,
    largeTitleExtent: largeTitleExtent ?? this.largeTitleExtent,
    largeTitleStyle: largeTitleStyle ?? this.largeTitleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    largeSubtitleStyle: largeSubtitleStyle ?? this.largeSubtitleStyle,
    gutter: gutter ?? this.gutter,
    controlGap: controlGap ?? this.controlGap,
    contentSpacing: contentSpacing ?? this.contentSpacing,
    revealExtent: revealExtent ?? this.revealExtent,
    revealSpring: revealSpring ?? this.revealSpring,
    hideSpring: hideSpring ?? this.hideSpring,
    inlineTitleDelay: inlineTitleDelay ?? this.inlineTitleDelay,
    largeTitleFadeDuration:
        largeTitleFadeDuration ?? this.largeTitleFadeDuration,
    largeTitleFadeCurve: largeTitleFadeCurve ?? this.largeTitleFadeCurve,
    titleCapsule: titleCapsule ?? this.titleCapsule,
  );

  GlassNavigationBarStyle merge(GlassNavigationBarStyle? other) => other == null
      ? this
      : GlassNavigationBarStyle(
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          titleAlignment: other.titleAlignment ?? titleAlignment,
          largeTitleAlignment: other.largeTitleAlignment ?? largeTitleAlignment,
          minimizationBehavior:
              other.minimizationBehavior ?? minimizationBehavior,
          minimizationThreshold:
              other.minimizationThreshold ?? minimizationThreshold,
          minimizationRestoration:
              other.minimizationRestoration ?? minimizationRestoration,
          minimizationSafeAreaAdjustment:
              other.minimizationSafeAreaAdjustment ??
              minimizationSafeAreaAdjustment,
          controlRowHeight: other.controlRowHeight ?? controlRowHeight,
          contentPadding: other.contentPadding ?? contentPadding,
          largeTitleExtent: other.largeTitleExtent ?? largeTitleExtent,
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
          contentSpacing: other.contentSpacing ?? contentSpacing,
          revealExtent: other.revealExtent ?? revealExtent,
          revealSpring: other.revealSpring ?? revealSpring,
          hideSpring: other.hideSpring ?? hideSpring,
          inlineTitleDelay: other.inlineTitleDelay ?? inlineTitleDelay,
          largeTitleFadeDuration:
              other.largeTitleFadeDuration ?? largeTitleFadeDuration,
          largeTitleFadeCurve: other.largeTitleFadeCurve ?? largeTitleFadeCurve,
          titleCapsule:
              titleCapsule?.merge(other.titleCapsule) ?? other.titleCapsule,
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
  GlassTitleAlignment alignment = GlassTitleAlignment.center,
  double subtitleOffset = 0,
}) {
  if (!large) {
    return _FitsRow(child: _titled(title, subtitle, subtitleStyle, alignment));
  }
  if (subtitle == null) return title;
  final line = DefaultTextStyle(
    style: subtitleStyle,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    child: subtitle,
  );
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: glassTitleCrossAlignment(alignment),
    children: [
      SizedBox(
        height: subtitleOffset,
        child: OverflowBox(
          alignment: glassTitleBoxAlignment(alignment),
          maxHeight: double.infinity,
          child: title,
        ),
      ),
      line,
    ],
  );
}

Widget _titled(
  Widget title,
  Widget? subtitle,
  TextStyle subtitleStyle,
  GlassTitleAlignment alignment,
) {
  if (subtitle == null) return title;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: glassTitleCrossAlignment(alignment),
    children: [
      title,
      DefaultTextStyle(
        style: subtitleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: subtitle,
      ),
    ],
  );
}

AlignmentGeometry glassTitleBoxAlignment(GlassTitleAlignment alignment) =>
    switch (alignment) {
      GlassTitleAlignment.center => Alignment.topCenter,
      GlassTitleAlignment.trailing => AlignmentDirectional.topEnd,
      _ => AlignmentDirectional.topStart,
    };

CrossAxisAlignment glassTitleCrossAlignment(GlassTitleAlignment alignment) =>
    switch (alignment) {
      GlassTitleAlignment.center => CrossAxisAlignment.center,
      GlassTitleAlignment.trailing => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };

/// Lays an inline title out at its own height and, when that is taller than
/// the bar's row (a two-line title at a large text size, say), scales it down
/// to fit rather than letting it overflow the row.
class _FitsRow extends SingleChildRenderObjectWidget {
  const _FitsRow({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFitsRow();
}

class _RenderFitsRow extends RenderProxyBox {
  double _scale = 1;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      BoxConstraints(maxWidth: constraints.maxWidth),
      parentUsesSize: true,
    );
    final height = child.size.height;
    _scale =
        constraints.hasBoundedHeight &&
            height > constraints.maxHeight &&
            height > 0
        ? constraints.maxHeight / height
        : 1;
    size = constraints.constrain(child.size * _scale);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final natural = child.getDryLayout(
      BoxConstraints(maxWidth: constraints.maxWidth),
    );
    final scale =
        constraints.hasBoundedHeight &&
            natural.height > constraints.maxHeight &&
            natural.height > 0
        ? constraints.maxHeight / natural.height
        : 1.0;
    return constraints.constrain(natural * scale);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (_scale == 1) return super.paint(context, offset);
    layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_scale == 1) return super.hitTestChildren(result, position: position);
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(_scale, _scale, 1),
      position: position,
      hitTest: (result, position) =>
          super.hitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(Matrix4.diagonal3Values(_scale, _scale, 1));
  }
}
