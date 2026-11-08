import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'glass_transition.dart';
import 'navigation_bar_style.dart';

/// Scroll-driven minimization shared by scaffold and sliver navigation chrome.
class NavigationBarMinimization {
  NavigationBarMinimization({required TickerProvider vsync})
    : progress = AnimationController(vsync: vsync);

  final AnimationController progress;
  GlassToolbarMinimizationBehavior _behavior =
      GlassToolbarMinimizationBehavior.never;
  GlassToolbarMinimizationRestoration _restoration =
      GlassToolbarMinimizationRestoration.automatic;
  double _pixels = 0,
      _collapseExtent = 0,
      _extent = 1,
      _threshold = 40 / 3,
      _hidden = 0;
  bool _scheduled = false, _disposed = false;

  void configure(
    GlassNavigationBarStyle style, {
    double? extent,
    double collapseExtent = 0,
  }) {
    final behavior =
        style.minimizationBehavior ??
        GlassToolbarMinimizationBehavior.automatic;
    if (behavior != _behavior) _hidden = 0;
    _behavior = behavior;
    _restoration =
        style.minimizationRestoration ??
        GlassToolbarMinimizationRestoration.automatic;
    _collapseExtent = collapseExtent;
    if (extent != null) setExtent(extent);
    _threshold = style.minimizationThreshold ?? 40 / 3;
    _hidden = _hidden.clamp(0.0, _extent);
    _publish();
  }

  void setExtent(double extent) {
    final fraction = _hidden / _extent;
    _extent = math.max(1.0, extent);
    _hidden = fraction * _extent;
  }

  void update(ScrollMetrics metrics, {bool dimensionsChanged = false}) {
    if (metrics.axis != Axis.vertical) return;
    final pixels = (metrics.pixels - metrics.minScrollExtent)
        .clamp(
          0.0,
          math.max(0.0, metrics.maxScrollExtent - metrics.minScrollExtent),
        )
        .toDouble();
    final delta =
        math.max(0.0, pixels - _collapseExtent - _threshold) -
        math.max(0.0, _pixels - _collapseExtent - _threshold);
    _pixels = pixels;
    if (dimensionsChanged && pixels != 0) return;
    switch (_behavior) {
      case GlassToolbarMinimizationBehavior.automatic:
      case GlassToolbarMinimizationBehavior.never:
        _hidden = 0;
      case GlassToolbarMinimizationBehavior.onScrollDown:
        if (pixels == 0) {
          _hidden = 0;
        } else if (delta > 0 ||
            _restoration != GlassToolbarMinimizationRestoration.atScrollEdge) {
          _hidden = (_hidden + delta).clamp(0.0, _extent);
        }
      case GlassToolbarMinimizationBehavior.onScrollUp:
        _hidden = (_hidden - delta).clamp(0.0, _extent);
    }
    _publish();
  }

  void _publish() {
    final value = _hidden / _extent;
    if (progress.value == value) return;
    // Viewports can deliver scroll notifications while updating their dimensions.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (!_scheduled) {
        _scheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scheduled = false;
          if (!_disposed) _publish();
        });
      }
      return;
    }
    progress.value = value;
  }

  void dispose() {
    _disposed = true;
    progress.dispose();
  }
}

/// Fades glass through its recipe, keeping the live backdrop available.
class NavigationBarPresence extends StatelessWidget {
  const NavigationBarPresence({
    super.key,
    required this.progress,
    required this.child,
  });
  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: progress,
    builder: (context, child) {
      final hidden = progress.value >= 1;
      return ExcludeFocus(
        excluding: hidden,
        child: IgnorePointer(
          ignoring: hidden,
          child: ExcludeSemantics(
            excluding: hidden,
            child: _BarVisibility(
              hidden: hidden,
              child: LiquidPrismPresence(
                progress: ReverseAnimation(progress),
                materialize: false,
                contentBlur: 0,
                child: child!,
              ),
            ),
          ),
        ),
      );
    },
    child: child,
  );
}

// Preserve layout at the hidden endpoint without isolating the glass backdrop.
class _BarVisibility extends SingleChildRenderObjectWidget {
  const _BarVisibility({required this.hidden, required super.child});
  final bool hidden;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBarVisibility(hidden);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBarVisibility renderObject,
  ) {
    renderObject.hidden = hidden;
  }
}

class _RenderBarVisibility extends RenderProxyBox {
  _RenderBarVisibility(this._hidden);
  bool _hidden;
  set hidden(bool value) {
    if (_hidden == value) return;
    _hidden = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hidden) super.paint(context, offset);
  }
}
