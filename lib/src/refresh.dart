import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';
import 'system_chrome.dart';

/// Pull to refresh for `LiquidPrismScaffold`: a black drop that the pull draws
/// out of the Dynamic Island, a notch, or the top edge where the view has
/// neither, holding a ring that fills from the top. At the trigger the drop
/// pinches off into a circle; released, it floats below its anchor and spins
/// until the refresh completes, shows a check, then merges back.
///
/// The scaffold forwards its scroll notifications to [GlassRefreshLayerState]
/// and stacks this layer over its chrome; the layer never takes pointers and
/// never moves the content.
@internal
class GlassRefreshLayer extends StatefulWidget {
  const GlassRefreshLayer({
    super.key,
    required this.onRefresh,
    this.sideInsets = EdgeInsets.zero,
    this.barCenter,
    this.sensorHousing = true,
  });

  final Future<void> Function() onRefresh;

  /// The content's horizontal insets, such as iPhone Duo's rail: a drop from
  /// the top edge is centred between them.
  final EdgeInsets sideInsets;

  /// The vertical centre of the top bar's controls. The circle rests on this
  /// line while refreshing when that keeps it clear of its anchor; null rests
  /// it just below the anchor.
  final double? barCenter;

  /// Whether the drop may anchor to the Dynamic Island or a notch. False for
  /// a layout that doesn't start at the screen's top edge, such as a sheet.
  final bool sensorHousing;

  /// The drop's height budget below the top edge.
  static const extent = 260.0;

  @override
  State<GlassRefreshLayer> createState() => GlassRefreshLayerState();
}

enum _Phase { idle, refreshing, done }

@internal
class GlassRefreshLayerState extends State<GlassRefreshLayer>
    with TickerProviderStateMixin {
  /// Overscroll, in logical pixels, at which a release starts a refresh.
  static const trigger = 84.0;

  /// How far below the trigger a pull must fall back to stop being armed, so
  /// a pull held at the trigger doesn't chatter.
  static const _disarmSlack = 10.0;

  /// The pull at which the drop has started to show, for its first haptic.
  static const _emergedPull = 10.0;

  /// How long the indicator spins at least, so a fast refresh still reads.
  static const _minimumRefresh = Duration(milliseconds: 650);

  /// The completed mark's animation, and how long it stays before the drop
  /// returns.
  static const _doneDuration = Duration(milliseconds: 720);
  static const _doneHold = Duration(milliseconds: 1050);

  static final _settle = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 480),
    bounce: 0.28,
  );
  static final _retract = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 520),
  );
  static final _pinch = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 360),
  );
  static final _swellSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 420),
    bounce: 0.5,
  );

  static Future<ui.FragmentProgram?>? _loading;
  static ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;

  /// The tracked pull: overscroll past the top that a finger started.
  final _pull = ValueNotifier<double>(0);

  /// The extension springs hold: the resting circle while refreshing, and the
  /// return after a release that scroll physics don't animate.
  late final _hold = RetargetableGlassSpring(vsync: this);

  /// 1 once the drop has pinched off its anchor into a circle.
  late final _detach = RetargetableGlassSpring(vsync: this);

  /// 1 while the pull is armed and still held: the circle and its ring swell
  /// and breathe, asking for the release.
  late final _swell = RetargetableGlassSpring(vsync: this);

  /// The filled ring's hand-off to the spinning one.
  late final _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  /// The completed mark.
  late final _done = AnimationController(vsync: this, duration: _doneDuration);

  /// Seconds the indicator has been breathing or spinning.
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _time.value = elapsed.inMicroseconds / 1e6,
  );

  bool _dragging = false;
  bool _tracking = false;
  bool _emerged = false;
  bool _armed = false;
  double _clampPull = 0;
  _Phase _phase = _Phase.idle;
  _Anchor _anchor = const _Anchor.edge();
  Timer? _doneTimer;

  @override
  void initState() {
    super.initState();
    // Subscribes, so the island or notch is known before the first pull.
    SystemChromeListener.instance.island;
    _hold.addStatusListener(_onHoldStatus);
    if (_program == null) {
      _loading ??=
          ui.FragmentProgram.fromAsset(
                'packages/liquid_prism/shaders/refresh.frag',
              )
              .then<ui.FragmentProgram?>((program) => _program = program)
              .catchError((Object error) {
                debugPrint('LiquidPrism: refresh shader unavailable: $error');
                return null;
              });
      _loading!.then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _ticker.dispose();
    _hold.dispose();
    _detach.dispose();
    _swell.dispose();
    _run.dispose();
    _done.dispose();
    _pull.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  bool get _immediate => MediaQuery.disableAnimationsOf(context);

  _DropGeometry _geometryFor(double width) => _DropGeometry(
    _anchor,
    width: width,
    sideInsets: widget.sideInsets,
    barCenter: widget.barCenter,
  );

  double _extensionFor(double width) =>
      math.max(_geometryFor(width).extensionFor(_pull.value), _hold.value);

  double get _width => context.size?.width ?? 0;

  /// Follows a scroll notification from the scroll view that refreshes.
  void handleScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axisDirection != AxisDirection.down) return;
    switch (notification) {
      case ScrollStartNotification(:final dragDetails):
        _setDragging(dragDetails != null);
      case ScrollUpdateNotification(:final dragDetails, :final scrollDelta):
        if (_clampPull > 0 && (scrollDelta ?? 0) > 0) {
          _clampPull = math.max(0, _clampPull - scrollDelta!);
        }
        _setDragging(dragDetails != null);
      case OverscrollNotification(:final dragDetails, :final overscroll):
        // Clamping physics report the pull instead of moving the content.
        if (dragDetails != null && overscroll < 0) {
          _clampPull += -overscroll * 0.55;
        }
        _setDragging(dragDetails != null);
      case ScrollEndNotification():
        _setDragging(false);
      default:
        break;
    }
    final over =
        math.max(0.0, metrics.minScrollExtent - metrics.pixels) + _clampPull;
    // A pull that catches the completed circle, showing its check or on its
    // way back, starts afresh rather than being ignored under that check.
    if (_dragging && over > 0 && _phase == _Phase.done) {
      _return();
      _becomeIdle();
    }
    // Only a finger starts a pull; the bounce of a fling to the top doesn't.
    if (_dragging && over > 0 && !_tracking) {
      _tracking = true;
      _chooseAnchor();
    }
    if (!_dragging && over <= 0) _tracking = _emerged = false;
    _pull.value = _tracking ? over : 0;
    if (!_dragging || _phase != _Phase.idle) return;
    if (!_emerged && over >= _emergedPull) {
      _emerged = true;
      _haptic(HapticFeedback.lightImpact);
    }
    _setArmed(over >= (_armed ? trigger - _disarmSlack : trigger));
  }

  /// Feedback at three moments: the drop starting to leave its anchor, the
  /// pinch-off that arms the refresh, and the refresh completing.
  void _haptic(Future<void> Function() feedback) {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    unawaited(feedback());
  }

  void _setDragging(bool dragging) {
    if (_dragging && !dragging) _release();
    _dragging = dragging;
  }

  void _setArmed(bool armed) {
    if (armed == _armed) return;
    _armed = armed;
    springGlass(_detach, armed ? 1 : 0, _pinch, immediate: _immediate);
    springGlass(_swell, armed ? 1 : 0, _swellSpring, immediate: _immediate);
    if (armed) {
      _haptic(HapticFeedback.mediumImpact);
      _restartClock();
    } else {
      _ticker.stop();
    }
  }

  void _restartClock() {
    _ticker.stop();
    _time.value = 0;
    unawaited(_ticker.start());
  }

  void _release() {
    final extension = _extensionFor(_width);
    final clamped = _clampPull > 0;
    _clampPull = 0;
    if (_phase != _Phase.idle) return;
    if (_armed) {
      // The circle stays pinched off; only the held swell lets go.
      _armed = false;
      springGlass(_swell, 0, _swellSpring, immediate: _immediate);
      unawaited(_refresh(extension));
    } else if (clamped) {
      _hold.value = extension;
      springGlass(_hold, 0, _retract, immediate: _immediate);
    }
  }

  /// Chooses the anchor for this pull: the island or notch when this layer
  /// starts at the screen's top edge and contains it, its own top edge if not.
  void _chooseAnchor() {
    if (_phase != _Phase.idle || _hold.value > 0.5) return;
    _anchor = const _Anchor.edge();
    final box = context.findRenderObject();
    if (!widget.sensorHousing || box is! RenderBox || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    if (origin.dy.abs() >= 1) return;
    Rect? local(Rect? global) {
      final shifted = global?.shift(-origin);
      return shifted != null &&
              shifted.left >= 0 &&
              shifted.right <= box.size.width
          ? shifted
          : null;
    }

    final chrome = SystemChromeListener.instance;
    if (local(chrome.island.value) case final island?) {
      _anchor = _Anchor.island(island);
    } else if (local(chrome.notch.value) case final notch?) {
      _anchor = _Anchor.notch(notch);
    }
  }

  Future<void> _refresh(double from) async {
    setState(() => _phase = _Phase.refreshing);
    _hold.value = from;
    springGlass(
      _hold,
      _geometryFor(_width).rest,
      _settle,
      immediate: _immediate,
    );
    _restartClock();
    unawaited(_run.forward(from: 0));
    final minimum = Future<void>.delayed(_minimumRefresh);
    try {
      await widget.onRefresh();
    } finally {
      await minimum;
      if (mounted) _finish();
    }
  }

  void _finish() {
    setState(() => _phase = _Phase.done);
    unawaited(_done.forward(from: 0));
    _haptic(HapticFeedback.successNotification);
    _doneTimer = Timer(_doneHold, () {
      if (!mounted) return;
      _return();
      if (_immediate) _reset();
    });
  }

  /// Sends the circle back: it rises and the neck regrows, so it merges into
  /// its anchor.
  void _return() {
    _doneTimer?.cancel();
    springGlass(_hold, 0, _retract, immediate: _immediate);
    springGlass(_detach, 0, _retract, immediate: _immediate);
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status.isAnimating || _phase != _Phase.done) return;
    if (_hold.value.abs() < 1) _reset();
  }

  /// The drop is back in its anchor.
  void _reset() {
    if (_phase == _Phase.idle) return;
    _hold.value = 0;
    _detach.value = 0;
    _becomeIdle();
  }

  /// Ends the refresh's indicator states, leaving the drop where its springs
  /// have it.
  void _becomeIdle() {
    _ticker.stop();
    _swell.value = 0;
    _run.value = 0;
    _done.value = 0;
    setState(() => _phase = _Phase.idle);
  }

  @override
  Widget build(BuildContext context) {
    if (_program != null && _shader == null) {
      _shader = _program!.fragmentShader();
    }
    final paint = RepaintBoundary(
      child: CustomPaint(
        painter: _DropPainter(
          state: this,
          shader: _shader,
          pixel: 1 / MediaQuery.devicePixelRatioOf(context),
          repaint: Listenable.merge([
            _pull,
            _hold,
            _detach,
            _swell,
            _run,
            _done,
            _time,
          ]),
        ),
        child: const SizedBox.expand(),
      ),
    );
    return IgnorePointer(
      child: _phase == _Phase.refreshing
          ? Semantics(liveRegion: true, label: 'Refreshing', child: paint)
          : paint,
    );
  }
}

/// What the drop grows out of, in the layer's coordinates.
@immutable
class _Anchor {
  /// The layer's top edge.
  const _Anchor.edge() : island = null, notch = null;

  /// The Dynamic Island: a pill the drop leaves through its lower half.
  const _Anchor.island(Rect this.island) : notch = null;

  /// A notch: the drop leaves through its lower edge, as from the top edge.
  const _Anchor.notch(Rect this.notch) : island = null;

  final Rect? island;
  final Rect? notch;
}

/// Where the drop is for an extension: how far its tip has travelled from its
/// hidden start inside the anchor.
class _DropGeometry {
  _DropGeometry(
    _Anchor anchor, {
    required this.width,
    required this.sideInsets,
    this.barCenter,
  }) : island = anchor.island?.deflate(_islandInset),
       notch = anchor.notch;

  /// The circle's radius once it has left the anchor.
  static const radius = 18.0;

  /// The neck's radius where it leaves the anchor, and at its thinnest before
  /// it pinches off.
  static const _neck = 14.0;
  static const _thinNeck = 7.5;

  /// The gap between the anchor and the circle once it has pinched off.
  static const _gap = 9.0;

  /// The island is drawn a hair smaller than reported, so none of it shows
  /// around the pill the system draws over the sensors.
  static const _islandInset = 0.5;

  /// A notch's lower corners are rounded; the drop's flare stays this far
  /// inside its sides, where its lower edge is straight.
  static const _notchCorner = 22.0;

  final Rect? island;
  final Rect? notch;
  final double width;
  final EdgeInsets sideInsets;
  final double? barCenter;

  double get centerX =>
      island?.center.dx ??
      notch?.center.dx ??
      (sideInsets.left + width - sideInsets.right) / 2;

  /// The straight edge the drop leaves, without an island: a notch's lower
  /// edge or the top of the layer.
  double get edgeY => notch?.bottom ?? 0;

  /// The neck's fixed upper end: the island's middle, or above the edge.
  double get neckY => island?.center.dy ?? edgeY - (radius + 6);

  /// The circle's resting height while refreshing: level with the bar's
  /// controls, and never closer to its anchor than the pinched-off gap.
  double get restY =>
      math.max((island?.bottom ?? edgeY) + _gap + radius, barCenter ?? 0);

  /// The extension at rest.
  double get rest => restY - neckY;

  /// The extension a pull produces: it reaches rest at the trigger, where the
  /// drop pinches off, then drifts on slowly.
  double extensionFor(double pull) {
    const trigger = GlassRefreshLayerState.trigger;
    return pull <= trigger
        ? pull * rest / trigger
        : rest + (pull - trigger) * 0.22;
  }

  double tipY(double extension) => neckY + extension;

  double tipRadius(double extension) =>
      ui.lerpDouble(_neck, radius, (extension / 16).clamp(0.0, 1.0))!;

  double get _maxBlend => island == null ? 40.0 : 32.0;

  /// The neck thins as the drop nears its rest, then pinches off as [detach]
  /// goes to 1: a radius below zero keeps it out of every union.
  double neckRadius(double extension, double detach) {
    final stretch = ((extension - (rest - 16)) / 16).clamp(0.0, 1.0);
    final attached = ui.lerpDouble(_neck, _thinNeck, stretch)!;
    return ui.lerpDouble(attached, -16, detach.clamp(0.0, 1.0))!;
  }

  /// The union's blend radius: the flare where the drop leaves its anchor,
  /// gone once it has pinched off.
  double blend(double extension, double detach) =>
      _maxBlend *
      (extension / 14).clamp(0.0, 1.0) *
      (1 - detach.clamp(0.0, 1.0));

  double opacity(double extension) => (extension / 5).clamp(0.0, 1.0);

  /// How much of the indicator has left the anchor.
  double emergence(double extension) =>
      ((extension - (rest - 18)) / 12).clamp(0.0, 1.0);

  /// The area the drop may paint down to [bottom] with [reach] to each side:
  /// the island's own width at least, a notch's straight edge at most.
  Rect bounds(Size size, double bottom, double reach) {
    var left = centerX - reach, right = centerX + reach;
    if (island case final island?) {
      left = math.min(left, island.left);
      right = math.max(right, island.right);
    } else if (notch case final notch?) {
      left = math.max(left, notch.left + _notchCorner);
      right = math.min(right, notch.right - _notchCorner);
    }
    return Rect.fromLTRB(
      math.max(0, left),
      math.max(0, island?.top ?? 0),
      math.min(size.width, right),
      math.min(size.height, bottom),
    );
  }
}

class _DropPainter extends CustomPainter {
  _DropPainter({
    required this.state,
    required this.shader,
    required this.pixel,
    required super.repaint,
  });

  final GlassRefreshLayerState state;
  final ui.FragmentShader? shader;
  final double pixel;

  static const _ring = 8.0;
  static const _stroke = 2.2;
  static const _white = Color(0xFFFFFFFF);
  static const _black = Color(0xFF000000);

  @override
  void paint(Canvas canvas, Size size) {
    final extension = state._extensionFor(size.width);
    if (extension <= 0.01) return;
    final geometry = state._geometryFor(size.width);
    final swell = state._swell.value.clamp(0.0, 1.4);
    final cx = geometry.centerX;
    final tipY = geometry.tipY(extension);
    final radius = geometry.tipRadius(extension) + 2 * swell;
    final detach = state._detach.value;
    final neck = geometry.neckRadius(extension, detach);
    final blend = geometry.blend(extension, detach);
    final opacity = geometry.opacity(extension);
    final island = geometry.island;
    final bounds = geometry.bounds(
      size,
      tipY + radius + 2,
      radius + blend * 2 + 8,
    );
    if (bounds.isEmpty) return;
    if (shader case final shader?) {
      shader
        ..setFloat(0, pixel * 0.75)
        ..setFloat(1, opacity)
        ..setFloat(2, island?.left ?? 0)
        ..setFloat(3, island?.top ?? geometry.edgeY)
        ..setFloat(4, island?.width ?? 0)
        ..setFloat(5, island?.height ?? 0)
        ..setFloat(6, cx)
        ..setFloat(7, geometry.neckY)
        ..setFloat(8, tipY)
        ..setFloat(9, radius)
        ..setFloat(10, neck)
        ..setFloat(11, blend);
      canvas.drawRect(bounds, Paint()..shader = shader);
    } else {
      // Without the shader: the same silhouette, unblended.
      final fill = Paint()..color = _black.withValues(alpha: opacity);
      if (island != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(island, Radius.circular(island.height / 2)),
          fill,
        );
      }
      if (neck > 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            cx - neck,
            geometry.neckY - neck,
            cx + neck,
            tipY + neck,
            Radius.circular(neck),
          ),
          fill,
        );
      }
      canvas.drawCircle(Offset(cx, tipY), radius, fill);
    }
    final emergence = geometry.emergence(extension);
    if (emergence > 0) {
      _paintIndicator(canvas, Offset(cx, tipY), emergence, swell);
    }
  }

  static double _interval(double t, double begin, double end) =>
      ((t - begin) / (end - begin)).clamp(0.0, 1.0);

  void _paintIndicator(
    Canvas canvas,
    Offset center,
    double emergence,
    double swell,
  ) {
    final refreshing = state._phase != _Phase.idle;
    final time = state._time.value;
    final run = Curves.easeInOut.transform(state._run.value);
    final done = state._done.value;

    // Armed and still held, the ring grows, thickens and breathes: release.
    final breath = refreshing ? 0.0 : 0.05 * math.sin(time * 5.4) * swell;
    // The completed disc lands with a single soft bounce.
    final bump = 0.16 * math.sin(math.pi * _interval(done, 0.2, 0.7));
    final scale = (1 + 0.14 * swell + breath + bump) * (0.7 + 0.3 * emergence);
    final radius = _ring * scale;
    final width = (_stroke + 0.5 * swell) * scale;
    final white = _white.withValues(alpha: emergence);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    // Done: the ring closes, fills inward into a white disc, and a check is
    // drawn out of it in the drop's black.
    final fill = Curves.easeInOutCubic.transform(_interval(done, 0.18, 0.52));
    if (fill > 0) {
      canvas.drawCircle(center, radius + width / 2, Paint()..color = white);
      final hole = (radius - width / 2) * (1 - fill);
      if (hole > 0.2) canvas.drawCircle(center, hole, Paint()..color = _black);
      final drawn = Curves.easeOutCubic.transform(_interval(done, 0.46, 0.9));
      if (drawn > 0) {
        final mark = Path()
          ..moveTo(center.dx - 3.7 * scale, center.dy + 0.4 * scale)
          ..lineTo(center.dx - 1.1 * scale, center.dy + 3.0 * scale)
          ..lineTo(center.dx + 3.9 * scale, center.dy - 2.8 * scale);
        final metric = mark.computeMetrics().first;
        canvas.drawPath(
          metric.extractPath(0, metric.length * drawn),
          stroke
            ..strokeWidth = 2.4 * scale
            ..strokeJoin = StrokeJoin.round
            ..color = _black.withValues(alpha: emergence),
        );
      }
      return;
    }

    // The track the ring fills.
    canvas.drawCircle(
      center,
      radius,
      stroke..color = _white.withValues(alpha: 0.2 * emergence),
    );

    // Turns, clockwise from the top. Pulled, the ring fills from the top and
    // is whole at the trigger. Spinning, it is a comet whose tail breathes.
    // Done, the tail catches up and the ring is whole again.
    final double tail, sweep, tailAlpha;
    if (!refreshing) {
      tail = -0.25;
      sweep = (state._pull.value / GlassRefreshLayerState.trigger).clamp(
        0.0,
        1.0,
      );
      tailAlpha = 1;
    } else {
      final close = Curves.easeOut.transform(_interval(done, 0, 0.28));
      final spin = 0.44 + 0.26 * math.sin(time * 2.7);
      sweep = ui.lerpDouble(ui.lerpDouble(1, spin, run)!, 1, close)!;
      tail = -0.25 + time * 1.2 - sweep;
      tailAlpha = ui.lerpDouble(ui.lerpDouble(1, 0.05, run)!, 1, close)!;
    }
    if (sweep <= 0.004) return;
    final start = tail * 2 * math.pi;
    final stop = sweep.clamp(0.02, 0.94);
    final rect = Rect.fromCircle(center: center, radius: radius);
    stroke
      ..color = _white
      ..shader = SweepGradient(
        colors: [
          _white.withValues(alpha: tailAlpha * emergence),
          white,
          white,
          _white.withValues(alpha: tailAlpha * emergence),
        ],
        stops: [0, stop, math.min(stop + 0.05, 0.99), 1],
        transform: GradientRotation(start),
      ).createShader(rect);
    if (sweep >= 0.995) {
      canvas.drawCircle(center, radius, stroke);
    } else {
      canvas.drawArc(rect, start, sweep * 2 * math.pi, false, stroke);
    }
  }

  @override
  bool shouldRepaint(_DropPainter old) =>
      old.shader != shader || old.pixel != pixel || old.state != state;
}
