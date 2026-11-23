import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/prism_motion.dart';
import '../rendering/edge_blur.dart';
import '../rendering/edge_fade.dart';
import '../theme/prism_theme.dart';
import 'prism_scroll_edge_style.dart';

@internal
PrismScrollEdgeStyle navigationScrollEdgeStyle(
  PrismScrollEdgeStyle style,
  double presence,
) {
  if (presence == 1 || style.variant == PrismScrollEdgeVariant.hard) {
    return style;
  }
  final extension = style.extension ?? PrismScrollEdgeStyle.defaultExtension;
  return style.copyWith(extension: extension * presence);
}

/// Progressive blur and fade beneath navigation chrome or scroll edges.
class PrismScrollEdge extends StatelessWidget {
  /// Creates a progress-driven navigation scroll-edge effect.
  const PrismScrollEdge({
    super.key,
    required this.progress,
    this.edge = PrismEdge.top,
    this.color,
    this.style,
  }) : _fade = null;

  /// Fades a scroll view at edges with content beyond the viewport.
  const PrismScrollEdge.fade({
    super.key,
    required Widget child,
    this.color,
    double extent = 56,
    double? endExtent,
    bool start = true,
    bool end = true,
    Axis axis = Axis.vertical,
    double sigma = 3,
    double fadeOpacity = 1,
    double plateau = 0,
    this.style,
  }) : progress = 0,
       edge = PrismEdge.top,
       _fade = (
         child: child,
         extent: extent,
         endExtent: endExtent,
         start: start,
         end: end,
         axis: axis,
         sigma: sigma,
         fadeOpacity: fadeOpacity,
         plateau: plateau,
       ),
       assert(extent >= 0),
       assert(endExtent == null || endExtent >= 0),
       assert(sigma >= 0),
       assert(fadeOpacity >= 0 && fadeOpacity <= 1),
       assert(plateau >= 0 && plateau < 1);

  final ({
    Widget child,
    double extent,
    double? endExtent,
    bool start,
    bool end,
    Axis axis,
    double sigma,
    double fadeOpacity,
    double plateau,
  })?
  _fade;

  /// Effect strength clamped to the range from zero to one.
  final double progress;

  /// Edge at which the effect is strongest.
  final PrismEdge edge;

  /// Fade surface color; null inherits the edge style.
  final Color? color;

  /// Local appearance overrides merged over the component theme.
  final PrismScrollEdgeStyle? style;

  /// Maps scroll offset to normalized edge strength over [revealExtent].
  static double progressFor(
    double scrollOffset, {
    double revealExtent = PrismScrollEdgeStyle.defaultRevealExtent,
  }) => (scrollOffset / revealExtent).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final fade = _fade;
    if (fade != null) {
      return _PrismScrollFade(
        color: color,
        extent: fade.extent,
        endExtent: fade.endExtent,
        start: fade.start,
        end: fade.end,
        axis: fade.axis,
        sigma: fade.sigma,
        fadeOpacity: fade.fadeOpacity,
        plateau: fade.plateau,
        style: style,
        child: fade.child,
      );
    }
    final strength = progress.clamp(0.0, 1.0);
    if (strength <= 0) return const SizedBox.shrink();
    final resolved = PrismScrollEdgeStyle.resolve(context, style);
    final hard = resolved.variant == PrismScrollEdgeVariant.hard;
    final extension =
        resolved.extension ??
        (hard ? 0 : PrismScrollEdgeStyle.defaultExtension);
    final floor =
        resolved.floor ?? (hard ? PrismScrollEdgeStyle.defaultHardFloor : 0);
    final falloff =
        resolved.falloff ??
        (hard
            ? PrismScrollEdgeStyle.defaultHardFalloff
            : PrismScrollEdgeStyle.defaultFalloff);
    final sigma =
        resolved.sigma ??
        (hard
            ? PrismScrollEdgeStyle.defaultHardSigma
            : PrismScrollEdgeStyle.defaultSigma);
    final fadeColor = color ?? resolved.fadeColor;
    final opacity =
        resolved.fadeOpacity ??
        (edge == PrismEdge.bottom
            ? PrismScrollEdgeStyle.defaultBottomFadeOpacity
            : PrismScrollEdgeStyle.defaultFadeOpacity);
    final haze = resolved.haze ?? PrismScrollEdgeStyle.defaultHaze;
    final hazeOpacity =
        resolved.hazeOpacity ?? PrismScrollEdgeStyle.defaultHazeOpacity;
    final hairline = hard && (resolved.hairline ?? true);
    final pixel = 1 / MediaQuery.devicePixelRatioOf(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: edge == PrismEdge.bottom ? -extension : 0,
          bottom: edge == PrismEdge.top ? -extension : 0,
          left: edge == PrismEdge.right ? -extension : 0,
          right: edge == PrismEdge.left ? -extension : 0,
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final extent = edge.isHorizontal
                    ? constraints.maxHeight
                    : constraints.maxWidth;
                if (!extent.isFinite || extent <= 0) {
                  return const SizedBox.shrink();
                }
                return PrismEdgeBlur(
                  edges: [
                    PrismEdgeBlurStrip(
                      edge: edge,
                      extent: extent,
                      sigma: sigma * strength,
                      plateau: extent <= falloff ? 0 : 1 - falloff / extent,
                      floor: floor,
                      fadeColor: fadeColor,
                      fadeOpacity: opacity * strength,
                      fadeFloor: hard ? 1 : null,
                      haze: haze,
                      hazeOpacity: hazeOpacity * strength,
                      hazePlateau: hard
                          ? 1
                          : PrismScrollEdgeStyle.defaultHazePlateau,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (hairline)
          Positioned(
            top: edge == PrismEdge.bottom || !edge.isHorizontal ? 0 : null,
            bottom: edge == PrismEdge.top || !edge.isHorizontal ? 0 : null,
            left: edge == PrismEdge.right || edge.isHorizontal ? 0 : null,
            right: edge == PrismEdge.left || edge.isHorizontal ? 0 : null,
            width: edge.isHorizontal ? null : pixel,
            height: edge.isHorizontal ? pixel : null,
            child: IgnorePointer(
              child: Opacity(
                opacity: strength,
                child: ColoredBox(
                  color: PrismScrollEdgeStyle.hairlineColorFor(
                    PrismTheme.brightnessOf(context),
                  ),
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
      ..add(EnumProperty<PrismEdge>('edge', edge))
      ..add(ColorProperty('color', color, defaultValue: null));
  }
}

class _PrismScrollFade extends StatefulWidget {
  const _PrismScrollFade({
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

  final Widget child;

  final Color? color;

  final double extent;
  final double? endExtent;

  final bool start;

  final bool end;

  final Axis axis;

  final double sigma;

  final double fadeOpacity;

  final double plateau;

  final PrismScrollEdgeStyle? style;

  @override
  State<_PrismScrollFade> createState() => __PrismScrollFadeState();

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

class __PrismScrollFadeState extends State<_PrismScrollFade>
    with TickerProviderStateMixin {
  late final _start = RetargetablePrismSpring(vsync: this);
  late final _end = RetargetablePrismSpring(vsync: this);
  bool _wantStart = false, _wantEnd = false;

  bool _initialised = false;

  SpringDescription get _spring =>
      (PrismScrollEdgeStyle.resolve(context, widget.style).spring ??
              const PrismSpring(
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
      springPrism(_start, wantStart ? 1 : 0, _spring, immediate: immediate);
    }
    if (wantEnd != _wantEnd) {
      _wantEnd = wantEnd;
      springPrism(_end, wantEnd ? 1 : 0, _spring, immediate: immediate);
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
        return PrismEdgeBlur(
          edges: [
            if (start > 0.001)
              PrismEdgeBlurStrip(
                edge: vertical ? PrismEdge.top : PrismEdge.left,
                extent: widget.extent,
                sigma: widget.sigma * start,
                plateau: widget.plateau,
                fadeColor: widget.color,
                fadeOpacity: widget.fadeOpacity * start,
              ),
            if (end > 0.001)
              PrismEdgeBlurStrip(
                edge: vertical ? PrismEdge.bottom : PrismEdge.right,
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

@internal
class ScrollEdgeProgressBuilder extends StatefulWidget {
  const ScrollEdgeProgressBuilder({
    super.key,
    required this.listenable,
    required this.progress,
    required this.builder,
  });

  final Listenable listenable;

  final ValueGetter<double> progress;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<ScrollEdgeProgressBuilder> createState() =>
      _ScrollEdgeProgressBuilderState();
}

class _ScrollEdgeProgressBuilderState extends State<ScrollEdgeProgressBuilder> {
  late double _progress = widget.progress();
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_changed);
  }

  @override
  void didUpdateWidget(ScrollEdgeProgressBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listenable != oldWidget.listenable) {
      oldWidget.listenable.removeListener(_changed);
      widget.listenable.addListener(_changed);
    }
    _progress = widget.progress();
  }

  void _changed() {
    final progress = widget.progress();
    if (progress == _progress) return;

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (!_scheduled) {
        _scheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scheduled = false;
          if (mounted) _changed();
        });
      }
      return;
    }
    setState(() => _progress = progress);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _progress);
}
