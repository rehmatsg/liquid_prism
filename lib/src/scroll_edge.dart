import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'edge_fade.dart';
import 'glass.dart';
import 'motion.dart';
import 'theme.dart';

/// How a scroll edge effect ends at the bar's inner side.
enum GlassScrollEdgeVariant {
  /// Dissolves into the content a little past the bar, as under floating
  /// glass bar buttons.
  soft,

  /// Stops at the bar's inner side with a hard edge, as under a bar with a
  /// background. The blur and fade still ramp within the bar.
  hard,
}

/// Appearance of a scroll edge effect: the progressive blur and fade iOS
/// applies to content scrolled under a bar.
///
/// Unspecified fields inherit the theme, then the measured native defaults
/// (doc/native_scroll_edge_spec.md, iOS 27.0): a 1.5-point variable blur and
/// a half-opacity fade that hold full strength over the top third of the
/// effect and fall along [GlassEdgeFade.curve] over its remaining 98 points,
/// a 16-point haze blended in at half opacity, and 50 points of reach past
/// the bar. The hard variant blurs 2 points, keeps a quarter of its blur, its
/// whole fade and its whole haze to the bar's edge, and draws a hairline
/// there. The effect arrives over the first 16 points of scroll, which is
/// this package's reveal; native bars show it as soon as content is beneath.
@immutable
class GlassScrollEdgeStyle {
  const GlassScrollEdgeStyle({
    this.variant,
    this.sigma,
    this.falloff,
    this.extension,
    this.floor,
    this.fadeColor,
    this.fadeOpacity,
    this.haze,
    this.hazeOpacity,
    this.hairline,
    this.revealExtent,
    this.spring,
  }) : assert(sigma == null || sigma >= 0),
       assert(falloff == null || falloff >= 0),
       assert(extension == null || extension >= 0),
       assert(floor == null || (floor >= 0 && floor <= 1)),
       assert(fadeOpacity == null || (fadeOpacity >= 0 && fadeOpacity <= 1)),
       assert(haze == null || haze >= 0),
       assert(hazeOpacity == null || (hazeOpacity >= 0 && hazeOpacity <= 1)),
       assert(revealExtent == null || revealExtent > 0);

  /// Soft or hard. Defaults to [GlassScrollEdgeVariant.soft].
  final GlassScrollEdgeVariant? variant;

  /// Gaussian sigma at full strength, in logical pixels. Zero fades only.
  final double? sigma;

  /// Depth of the falloff, measured from the effect's inner end: blur and fade
  /// reach full strength this far in and hold it to the edge.
  final double? falloff;

  /// How far the effect reaches past the box it is given, so a bar's lower
  /// edge dissolves into the content instead of drawing a horizon. The hard
  /// variant defaults to none.
  final double? extension;

  /// Fraction of full strength kept at the effect's inner end, 0–1. The soft
  /// variant defaults to none; the hard variant keeps part of its blur and
  /// fade up to its edge.
  final double? floor;

  /// The surface content fades into. Null fades toward the color the widget
  /// is given, else blurs only.
  final Color? fadeColor;

  /// Opacity of the fade at the edge, 0–1. Below 1, content at the edge stays
  /// partly visible.
  final double? fadeOpacity;

  /// Sigma of the heavy blur blended into the effect ([GlassEdgeBlur.haze]).
  /// Zero leaves only the variable blur.
  final double? haze;

  /// The haze's opacity, 0–1.
  final double? hazeOpacity;

  /// Whether the hard variant draws a one-pixel 10% black line at its edge,
  /// as native bars do. Ignored by the soft variant.
  final bool? hairline;

  /// Scroll distance over which the effect fades in, in logical pixels.
  final double? revealExtent;

  /// Spring for effects that animate in and out ([LiquidPrismScrollFade]).
  final GlassSpring? spring;

  /// Keep existing fields when an argument is null.
  GlassScrollEdgeStyle copyWith({
    GlassScrollEdgeVariant? variant,
    double? sigma,
    double? falloff,
    double? extension,
    double? floor,
    Color? fadeColor,
    double? fadeOpacity,
    double? haze,
    double? hazeOpacity,
    bool? hairline,
    double? revealExtent,
    GlassSpring? spring,
  }) => GlassScrollEdgeStyle(
    variant: variant ?? this.variant,
    sigma: sigma ?? this.sigma,
    falloff: falloff ?? this.falloff,
    extension: extension ?? this.extension,
    floor: floor ?? this.floor,
    fadeColor: fadeColor ?? this.fadeColor,
    fadeOpacity: fadeOpacity ?? this.fadeOpacity,
    haze: haze ?? this.haze,
    hazeOpacity: hazeOpacity ?? this.hazeOpacity,
    hairline: hairline ?? this.hairline,
    revealExtent: revealExtent ?? this.revealExtent,
    spring: spring ?? this.spring,
  );

  /// Apply a partial override, retaining unspecified fields.
  GlassScrollEdgeStyle merge(GlassScrollEdgeStyle? other) => other == null
      ? this
      : GlassScrollEdgeStyle(
          variant: other.variant ?? variant,
          sigma: other.sigma ?? sigma,
          falloff: other.falloff ?? falloff,
          extension: other.extension ?? extension,
          floor: other.floor ?? floor,
          fadeColor: other.fadeColor ?? fadeColor,
          fadeOpacity: other.fadeOpacity ?? fadeOpacity,
          haze: other.haze ?? haze,
          hazeOpacity: other.hazeOpacity ?? hazeOpacity,
          hairline: other.hairline ?? hairline,
          revealExtent: other.revealExtent ?? revealExtent,
          spring: other.spring ?? spring,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlassScrollEdgeStyle &&
          other.variant == variant &&
          other.sigma == sigma &&
          other.falloff == falloff &&
          other.extension == extension &&
          other.floor == floor &&
          other.fadeColor == fadeColor &&
          other.fadeOpacity == fadeOpacity &&
          other.haze == haze &&
          other.hazeOpacity == hazeOpacity &&
          other.hairline == hairline &&
          other.revealExtent == revealExtent &&
          other.spring == spring;

  @override
  int get hashCode => Object.hash(
    variant,
    sigma,
    falloff,
    extension,
    floor,
    fadeColor,
    fadeOpacity,
    haze,
    hazeOpacity,
    hairline,
    revealExtent,
    spring,
  );

  // Measured on iOS 27.0; see doc/native_scroll_edge_spec.md.
  static const double defaultSigma = 1.5;
  static const double defaultFalloff = 98;
  static const double defaultExtension = 50;
  static const double defaultFadeOpacity = .5;
  static const double defaultHaze = 16;
  static const double defaultHazeOpacity = .5;
  static const double defaultHazePlateau = .34;
  static const double defaultRevealExtent = 16;

  /// The hard variant's defaults: a 2-point blur that keeps a quarter of its
  /// strength at the edge, falling over the lower 51 points of the bar, with
  /// no reach past it and the fade and haze held to the edge.
  static const double defaultHardSigma = 2;
  static const double defaultHardFalloff = 51;
  static const double defaultHardFloor = .25;
  static const Color hairlineColor = Color(0x1A000000);

  /// The style at [context]: theme, then [override].
  static GlassScrollEdgeStyle resolve(
    BuildContext context,
    GlassScrollEdgeStyle? override,
  ) => (LiquidPrismTheme.of(context).scrollEdge ?? const GlassScrollEdgeStyle())
      .merge(override);
}

/// The scroll edge effect of a bar: a progressive blur and partial fade of
/// whatever is painted beneath this box, strongest at [edge] and dissolving
/// [GlassScrollEdgeStyle.extension] past the opposite side.
///
/// Lay it in the bar's background, filling the bar's box (status bar
/// included) with the bar's title and controls painted above it, and drive
/// [progress] from the scroll offset with [progressFor]. It paints nothing at
/// zero progress and ignores pointers.
///
/// Inside a [LiquidPrismGroup] or [LiquidPrismScaffold] with the bar's glass
/// controls, the effect shares their backdrop captures and is cut out of their
/// contours, so the glass refracts the unblurred content beneath, as native
/// bar buttons do over a scroll edge effect. See [LiquidPrismEdgeBlur].
///
/// ```dart
/// SliverLayoutBuilder(
///   builder: (context, constraints) => SliverAppBar(
///     backgroundColor: Colors.transparent,
///     flexibleSpace: LiquidPrismScrollEdge(
///       progress: LiquidPrismScrollEdge.progressFor(constraints.scrollOffset),
///       color: Theme.of(context).scaffoldBackgroundColor,
///     ),
///     ...
///   ),
/// )
/// ```
class LiquidPrismScrollEdge extends StatelessWidget {
  const LiquidPrismScrollEdge({
    super.key,
    required this.progress,
    this.edge = GlassEdge.top,
    this.color,
    this.style,
  });

  /// The effect's strength, 0 (absent) to 1. Values outside are clamped.
  final double progress;

  /// The edge content scrolls under, where the effect is strongest.
  final GlassEdge edge;

  /// The surface content fades into. Null uses the style's color, else the
  /// effect blurs only.
  final Color? color;

  /// Overrides the theme's style field by field.
  final GlassScrollEdgeStyle? style;

  /// The strength for content scrolled [scrollOffset] under the bar, rising
  /// over the first [revealExtent] logical pixels.
  static double progressFor(
    double scrollOffset, {
    double revealExtent = GlassScrollEdgeStyle.defaultRevealExtent,
  }) => (scrollOffset / revealExtent).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final strength = progress.clamp(0.0, 1.0);
    if (strength <= 0) return const SizedBox.shrink();
    final resolved = GlassScrollEdgeStyle.resolve(context, style);
    final hard = resolved.variant == GlassScrollEdgeVariant.hard;
    final extension =
        resolved.extension ??
        (hard ? 0 : GlassScrollEdgeStyle.defaultExtension);
    final floor =
        resolved.floor ?? (hard ? GlassScrollEdgeStyle.defaultHardFloor : 0);
    final falloff =
        resolved.falloff ??
        (hard
            ? GlassScrollEdgeStyle.defaultHardFalloff
            : GlassScrollEdgeStyle.defaultFalloff);
    final sigma =
        resolved.sigma ??
        (hard
            ? GlassScrollEdgeStyle.defaultHardSigma
            : GlassScrollEdgeStyle.defaultSigma);
    final fade = color ?? resolved.fadeColor;
    final opacity =
        resolved.fadeOpacity ?? GlassScrollEdgeStyle.defaultFadeOpacity;
    final haze = resolved.haze ?? GlassScrollEdgeStyle.defaultHaze;
    final hazeOpacity =
        resolved.hazeOpacity ?? GlassScrollEdgeStyle.defaultHazeOpacity;
    final hairline = hard && (resolved.hairline ?? true);
    final pixel = 1 / MediaQuery.devicePixelRatioOf(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: edge == GlassEdge.bottom ? -extension : 0,
          bottom: edge == GlassEdge.top ? -extension : 0,
          left: edge == GlassEdge.right ? -extension : 0,
          right: edge == GlassEdge.left ? -extension : 0,
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final extent = edge.isHorizontal
                    ? constraints.maxHeight
                    : constraints.maxWidth;
                if (!extent.isFinite || extent <= 0) {
                  return const SizedBox.shrink();
                }
                return LiquidPrismEdgeBlur(
                  edges: [
                    GlassEdgeBlur(
                      edge: edge,
                      extent: extent,
                      sigma: sigma * strength,
                      plateau: extent <= falloff ? 0 : 1 - falloff / extent,
                      floor: floor,
                      fadeColor: fade,
                      fadeOpacity: opacity * strength,
                      fadeFloor: hard ? 1 : null,
                      haze: haze,
                      hazeOpacity: hazeOpacity * strength,
                      hazePlateau: hard
                          ? 1
                          : GlassScrollEdgeStyle.defaultHazePlateau,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (hairline)
          // Spanning the edge, a device pixel thick at its far side.
          Positioned(
            top: edge == GlassEdge.bottom || !edge.isHorizontal ? 0 : null,
            bottom: edge == GlassEdge.top || !edge.isHorizontal ? 0 : null,
            left: edge == GlassEdge.right || edge.isHorizontal ? 0 : null,
            right: edge == GlassEdge.left || edge.isHorizontal ? 0 : null,
            width: edge.isHorizontal ? null : pixel,
            height: edge.isHorizontal ? pixel : null,
            child: IgnorePointer(
              child: Opacity(
                opacity: strength,
                child: const ColoredBox(
                  color: GlassScrollEdgeStyle.hairlineColor,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('progress', progress))
      ..add(EnumProperty<GlassEdge>('edge', edge))
      ..add(ColorProperty('color', color, defaultValue: null));
  }
}

/// Fades and blurs the edges of a scrollable while content extends past them.
///
/// Wrap a scroll view without changing it. Each edge's effect is absent while
/// the content sits flush with that edge and springs in as the user scrolls
/// away, blurring the content under it with a [LiquidPrismEdgeBlur] and fading
/// it toward [color] along the same curve.
///
/// ```dart
/// LiquidPrismScrollFade(
///   color: background,
///   child: ListView(children: [...]),
/// )
/// ```
class LiquidPrismScrollFade extends StatefulWidget {
  const LiquidPrismScrollFade({
    super.key,
    required this.child,
    this.color,
    this.extent = 56,
    this.endExtent,
    this.start = true,
    this.end = true,
    this.axis = Axis.vertical,
    this.sigma = 3,
    this.fadeOpacity = 1,
    this.plateau = 0,
    this.style,
  }) : assert(extent >= 0),
       assert(endExtent == null || endExtent >= 0),
       assert(sigma >= 0),
       assert(fadeOpacity >= 0 && fadeOpacity <= 1),
       assert(plateau >= 0 && plateau < 1);

  /// The scroll view. Nested scroll views are ignored.
  final Widget child;

  /// The surface content fades into. Null blurs only.
  final Color? color;

  /// Depth of the leading edge's strip, and of the trailing edge's unless
  /// [endExtent] is set.
  final double extent;
  final double? endExtent;

  /// Whether to treat the leading edge (top, or left).
  final bool start;

  /// Whether to treat the trailing edge (bottom, or right).
  final bool end;

  /// Must match the scroll view's axis.
  final Axis axis;

  /// Gaussian sigma at the edge when fully shown. Zero fades only.
  final double sigma;

  /// Opacity of the fade at the edge when fully shown.
  final double fadeOpacity;

  /// Leading fraction of each strip held at full strength.
  final double plateau;

  /// Overrides the theme's [GlassScrollEdgeStyle.spring].
  final GlassScrollEdgeStyle? style;

  @override
  State<LiquidPrismScrollFade> createState() => _LiquidPrismScrollFadeState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<Axis>('axis', axis))
      ..add(DoubleProperty('extent', extent))
      ..add(DoubleProperty('endExtent', endExtent, defaultValue: null))
      ..add(ColorProperty('color', color, defaultValue: null))
      ..add(DoubleProperty('sigma', sigma, defaultValue: 3))
      ..add(DoubleProperty('fadeOpacity', fadeOpacity, defaultValue: 1));
  }
}

class _LiquidPrismScrollFadeState extends State<LiquidPrismScrollFade>
    with TickerProviderStateMixin {
  late final _start = RetargetableGlassSpring(vsync: this);
  late final _end = RetargetableGlassSpring(vsync: this);
  bool _wantStart = false, _wantEnd = false;
  // The first metrics decide without animating: a zero range on the first
  // frame may only mean layout is not finished, so wait for a real reading.
  bool _initialised = false;

  SpringDescription get _spring =>
      (GlassScrollEdgeStyle.resolve(context, widget.style).spring ??
              const GlassSpring(
                response: Duration(milliseconds: 320),
                bounce: 0,
              ))
          .description;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetrics metrics) {
    if (!mounted || metrics.axis != widget.axis) return false;
    final range = metrics.maxScrollExtent - metrics.minScrollExtent;
    final wantStart = range > 0 && metrics.pixels > metrics.minScrollExtent;
    final wantEnd = range > 0 && metrics.pixels < metrics.maxScrollExtent;
    if (!_initialised) {
      if (range <= 0) return false;
      _initialised = true;
      _wantStart = wantStart;
      _wantEnd = wantEnd;
      _start.value = wantStart ? 1 : 0;
      _end.value = wantEnd ? 1 : 0;
      return false;
    }
    final immediate = MediaQuery.disableAnimationsOf(context);
    if (wantStart != _wantStart) {
      _wantStart = wantStart;
      springGlass(_start, wantStart ? 1 : 0, _spring, immediate: immediate);
    }
    if (wantEnd != _wantEnd) {
      _wantEnd = wantEnd;
      springGlass(_end, wantEnd ? 1 : 0, _spring, immediate: immediate);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final vertical = widget.axis == Axis.vertical;
    return AnimatedBuilder(
      animation: Listenable.merge([_start, _end]),
      builder: (context, child) {
        final start = widget.start ? _start.value.clamp(0.0, 1.0) : 0.0;
        final end = widget.end ? _end.value.clamp(0.0, 1.0) : 0.0;
        return LiquidPrismEdgeBlur(
          edges: [
            if (start > 0.001)
              GlassEdgeBlur(
                edge: vertical ? GlassEdge.top : GlassEdge.left,
                extent: widget.extent,
                sigma: widget.sigma * start,
                plateau: widget.plateau,
                fadeColor: widget.color,
                fadeOpacity: widget.fadeOpacity * start,
              ),
            if (end > 0.001)
              GlassEdgeBlur(
                edge: vertical ? GlassEdge.bottom : GlassEdge.right,
                extent: widget.endExtent ?? widget.extent,
                sigma: widget.sigma * end,
                plateau: widget.plateau,
                fadeColor: widget.color,
                fadeOpacity: widget.fadeOpacity * end,
              ),
          ],
          child: child,
        );
      },
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
          child: widget.child,
        ),
      ),
    );
  }
}
