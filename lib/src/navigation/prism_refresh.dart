import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/core/prism_haptics.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/navigation/prism_system_chrome.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// Controls and observes a scaffold refresh operation.
class PrismRefreshController extends ChangeNotifier {
  PrismRefreshLayerState? _layer;
  bool _refreshing = false;

  /// Whether a refresh operation is currently running.
  bool get isRefreshing => _refreshing;

  /// Starts a refresh when attached, coalescing overlapping requests.
  Future<void> refresh() => _layer?._refreshFromCode() ?? Future<void>.value();

  void _setRefreshing(bool refreshing) {
    if (_refreshing == refreshing) return;
    _refreshing = refreshing;
    notifyListeners();
  }
}

@internal
class PrismRefreshLayer extends StatefulWidget {
  const new({
    super.key,
    required this.onRefresh,
    this.controller,
    this.sideInsets = EdgeInsets.zero,
    this.barCenter,
    this.sensorHousing = true,
    this.belowHeader = false,
    this.headerBoundary,
    this.contentDisplacement,
  });

  final Future<void> Function()? onRefresh;
  final PrismRefreshController? controller;

  final EdgeInsets sideInsets;

  final double? barCenter;

  final bool sensorHousing;

  final bool belowHeader;

  final ValueListenable<Rect>? headerBoundary;
  final ValueNotifier<double>? contentDisplacement;

  static const extent = 260.0;

  @override
  State<PrismRefreshLayer> createState() => PrismRefreshLayerState();
}

enum _Phase { idle, refreshing, done }

@internal
class PrismRefreshLayerState extends State<PrismRefreshLayer>
    with TickerProviderStateMixin {
  static const trigger = 84.0;

  static const compactSpacing = 24.0;
  static const double compactExtent =
      compactSpacing * 2 + _DropGeometry.radius * 2;

  static const _disarmSlack = 10.0;

  static const _emergedPull = 10.0;

  static const _minimumRefresh = Duration(milliseconds: 650);

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

  final _pull = ValueNotifier<double>(0);

  late final _hold = RetargetablePrismSpring(vsync: this);

  late final _detach = RetargetablePrismSpring(vsync: this);

  late final _swell = RetargetablePrismSpring(vsync: this);

  late final _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  late final _done = AnimationController(vsync: this, duration: _doneDuration);

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
  bool _belowHeader = false;
  Timer? _doneTimer;

  @override
  void initState() {
    super.initState();
    widget.controller?._layer = this;

    SystemChromeListener.instance.island;
    _hold.addStatusListener(_onHoldStatus);
    _hold.addListener(_updateDisplacement);
    _pull.addListener(_updateDisplacement);
    if (_program == null) {
      _loading ??=
          ui.FragmentProgram.fromAsset(
                'packages/liquid_prism/shaders/refresh.frag',
              )
              .then<ui.FragmentProgram?>((program) => _program = program)
              .catchError((Object error) {
                debugPrint('PrismRefresh: refresh shader unavailable: $error');
                return null;
              });
      unawaited(
        _loading!.then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
  }

  @override
  void didUpdateWidget(PrismRefreshLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.controller;
    if (previous == widget.controller) return;
    if (previous?._layer == this) {
      previous!
        .._layer = null
        .._refreshing = false;
    }
    widget.controller
      ?.._layer = this
      .._refreshing = _phase == _Phase.refreshing;
  }

  @override
  void dispose() {
    if (widget.controller?._layer == this) {
      widget.controller!
        .._layer = null
        .._refreshing = false;
    }
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

  double get _compactHoldExtent => math.max<double>(
    0,
    compactExtent - (widget.headerBoundary?.value.height ?? 0),
  );

  void _updateDisplacement() {
    widget.contentDisplacement?.value = _belowHeader
        ? math.max<double>(
            0,
            math.max(_pull.value, _hold.value * _compactHoldExtent / trigger) -
                math.max(0.0, _pull.value - _clampPull),
          )
        : 0;
  }

  bool get _immediate => MediaQuery.disableAnimationsOf(context);

  _DropGeometry _geometryFor(double width) => _DropGeometry(
    _anchor,
    width: width,
    sideInsets: widget.sideInsets,
    barCenter: widget.barCenter,
  );

  double _extensionFor(double width) => math.max(
    _belowHeader ? _pull.value : _geometryFor(width).extensionFor(_pull.value),
    _hold.value,
  );

  double get _width => context.size?.width ?? 0;

  void handleScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axisDirection != AxisDirection.down) return;
    if (widget.onRefresh == null) {
      _dragging = _tracking = _emerged = false;
      _clampPull = 0;
      _pull.value = 0;
      if (_phase == _Phase.idle) _setArmed(false, silent: true);
      return;
    }
    switch (notification) {
      case ScrollStartNotification(:final dragDetails):
        _setDragging(dragDetails != null);
      case ScrollUpdateNotification(:final dragDetails, :final scrollDelta):
        if (_clampPull > 0 && (scrollDelta ?? 0) > 0) {
          _clampPull = math.max<double>(0, _clampPull - scrollDelta!);
        }
        _setDragging(dragDetails != null);
      case OverscrollNotification(:final dragDetails, :final overscroll):
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
        math.max<double>(0, metrics.minScrollExtent - metrics.pixels) +
        _clampPull;

    if (_dragging && over > 0 && _phase == _Phase.done) {
      _return();
      _becomeIdle();
    }

    if (_dragging && over > 0 && !_tracking) {
      _tracking = true;
      _chooseAnchor();
    }
    if (!_dragging && over <= 0) _tracking = _emerged = false;
    _pull.value = _tracking ? over : 0;
    if (!_dragging || _phase != _Phase.idle) return;
    if (!_emerged && over >= _emergedPull) {
      _emerged = true;
      _haptic(PrismHapticKind.refreshPulled);
    }
    _setArmed(over >= (_armed ? trigger - _disarmSlack : trigger));
  }

  void _haptic(PrismHapticKind kind) {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    dispatchPrismHaptic(
      context,
      PrismHapticEvent(PrismHapticComponent.refresh, kind),
    );
  }

  void _setDragging(bool dragging) {
    if (_dragging && !dragging) _release();
    _dragging = dragging;
  }

  void _setArmed(bool armed, {bool silent = false}) {
    if (armed == _armed) return;
    _armed = armed;
    springPrism(_detach, armed ? 1 : 0, _pinch, immediate: _immediate);
    springPrism(_swell, armed ? 1 : 0, _swellSpring, immediate: _immediate);
    if (armed) {
      if (!silent) _haptic(PrismHapticKind.refreshArmed);
      _restartClock();
    } else {
      _ticker.stop();
    }
  }

  void _restartClock() {
    _ticker.stop();
    _time.value = 0;
    _ticker.start();
  }

  void _release() {
    final extension = _extensionFor(_width);
    final clamped = _clampPull > 0;
    _clampPull = 0;
    if (_phase != _Phase.idle) return;
    if (_armed) {
      _armed = false;
      _haptic(PrismHapticKind.refreshReleased);
      springPrism(_swell, 0, _swellSpring, immediate: _immediate);
      unawaited(_refresh(extension));
    } else if (clamped) {
      _hold.value = extension;
      springPrism(_hold, 0, _retract, immediate: _immediate);
    }
  }

  void _chooseAnchor() {
    if (_phase != _Phase.idle || _hold.value > 0.5) return;
    _belowHeader = widget.belowHeader;
    _anchor = const _Anchor.edge();
    if (_belowHeader) return;
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

  Future<void> _refreshFromCode() {
    if (widget.onRefresh == null) return Future<void>.value();
    if (_phase == _Phase.refreshing) return _running.future;
    if (_phase == _Phase.done) {
      _return();
      _becomeIdle();
    }
    _chooseAnchor();
    _armed = false;
    springPrism(_detach, 1, _pinch, immediate: _immediate);
    springPrism(_swell, 0, _swellSpring, immediate: _immediate);
    _haptic(PrismHapticKind.refreshArmed);
    final from = _extensionFor(_width);
    unawaited(_refresh(from));
    return _running.future;
  }

  late Completer<void> _running;

  Future<void> _refresh(double from) async {
    final running = _running = Completer<void>();
    widget.controller?._setRefreshing(true);
    setState(() => _phase = _Phase.refreshing);
    _hold.value = from;
    springPrism(
      _hold,
      _belowHeader ? trigger : _geometryFor(_width).rest,
      _settle,
      immediate: _immediate,
    );
    _restartClock();
    _run.forward(from: 0);
    final minimum = Future<void>.delayed(_minimumRefresh);

    var succeeded = false;
    try {
      final Future<Object?>? result = widget.onRefresh?.call();
      succeeded = await result != false;
    } finally {
      await minimum;
      if (mounted) {
        widget.controller?._setRefreshing(false);
        _finish(succeeded);
      }
      running.complete();
    }
  }

  void _finish(bool succeeded) {
    setState(() => _phase = _Phase.done);
    if (!succeeded) {
      _haptic(PrismHapticKind.refreshFailed);
      _return();
      if (_immediate) _reset();
      return;
    }
    _done.forward(from: 0);
    _haptic(PrismHapticKind.refreshSucceeded);
    _doneTimer = Timer(_doneHold, () {
      if (!mounted) return;
      _return();
      if (_immediate) _reset();
    });
  }

  void _return() {
    _doneTimer?.cancel();
    springPrism(_hold, 0, _retract, immediate: _immediate);
    springPrism(_detach, 0, _retract, immediate: _immediate);
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status.isAnimating || _phase != _Phase.done) return;
    if (_hold.value.abs() < 1) _reset();
  }

  void _reset() {
    if (_phase == _Phase.idle) return;
    _hold.value = 0;
    _detach.value = 0;
    _becomeIdle();
  }

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
          dark: PrismTheme.materialBrightnessOf(context) == Brightness.dark,
          repaint: Listenable.merge([
            _pull,
            _hold,
            _detach,
            _swell,
            _run,
            _done,
            _time,
            if (widget.headerBoundary != null) widget.headerBoundary!,
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

@immutable
class _Anchor {
  const new edge() : island = null, notch = null;

  const new island(Rect this.island) : notch = null;

  const new notch(Rect this.notch) : island = null;

  final Rect? island;
  final Rect? notch;
}

class _DropGeometry {
  new(
    _Anchor anchor, {
    required this.width,
    required this.sideInsets,
    this.barCenter,
  }) : island = anchor.island?.deflate(_islandInset),
       notch = anchor.notch;

  static const radius = 18.0;

  static const _neck = 14.0;
  static const _thinNeck = 7.5;

  static const _gap = 9.0;

  static const _islandInset = 0.5;

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

  double get edgeY => notch?.bottom ?? 0;

  double get neckY => island?.center.dy ?? edgeY - (radius + 6);

  double get restY =>
      math.max((island?.bottom ?? edgeY) + _gap + radius, barCenter ?? 0);

  double get rest => restY - neckY;

  double extensionFor(double pull) {
    const trigger = PrismRefreshLayerState.trigger;
    return pull <= trigger
        ? pull * rest / trigger
        : rest + (pull - trigger) * 0.22;
  }

  double tipY(double extension) => neckY + extension;

  double tipRadius(double extension) =>
      ui.lerpDouble(_neck, radius, (extension / 16).clamp(0.0, 1.0))!;

  double get _maxBlend => island == null ? 40.0 : 32.0;

  double neckRadius(double extension, double detach) {
    final stretch = ((extension - (rest - 16)) / 16).clamp(0.0, 1.0);
    final attached = ui.lerpDouble(_neck, _thinNeck, stretch)!;
    return ui.lerpDouble(attached, -16, detach.clamp(0.0, 1.0))!;
  }

  double blend(double extension, double detach) =>
      _maxBlend *
      (extension / 14).clamp(0.0, 1.0) *
      (1 - detach.clamp(0.0, 1.0));

  double opacity(double extension) => (extension / 5).clamp(0.0, 1.0);

  double emergence(double extension) =>
      ((extension - (rest - 18)) / 12).clamp(0.0, 1.0);

  Rect bounds(Size size, double bottom, double reach) {
    var left = centerX - reach;
    var right = centerX + reach;
    if (island case final island?) {
      left = math.min(left, island.left);
      right = math.max(right, island.right);
    } else if (notch case final notch?) {
      left = math.max(left, notch.left + _notchCorner);
      right = math.min(right, notch.right - _notchCorner);
    }
    return Rect.fromLTRB(
      math.max<double>(0, left),
      math.max<double>(0, island?.top ?? 0),
      math.min(size.width, right),
      math.min(size.height, bottom),
    );
  }
}

class _DropPainter extends CustomPainter {
  new({
    required this.state,
    required this.shader,
    required this.pixel,
    required this.dark,
    required super.repaint,
  });

  final PrismRefreshLayerState state;
  final ui.FragmentShader? shader;
  final double pixel;
  final bool dark;

  static const _ring = 8.0;
  static const _stroke = 2.2;
  static const _white = Color(0xFFFFFFFF);
  static const _black = Color(0xFF000000);
  static const _outlineWidth = 1.0;
  static const _outlineAlpha = 0.22;

  @override
  void paint(Canvas canvas, Size size) {
    final extension = state._extensionFor(size.width);
    if (extension <= 0.01) return;
    if (state._belowHeader) {
      _paintBelowHeader(canvas, size, extension);
      return;
    }
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
    final anchorBottom = island?.bottom ?? geometry.edgeY;

    final bottom =
        math.max(anchorBottom, tipY + radius) + (14 + blend) / 6 + pixel;
    final bounds = geometry.bounds(size, bottom, radius + blend * 2 + 8);
    if (bounds.isEmpty) return;
    final detached = neck <= -14 && tipY - radius - anchorBottom >= blend;
    if (detached) {
      canvas.drawCircle(
        Offset(cx, tipY),
        radius,
        Paint()..color = _black.withValues(alpha: opacity),
      );
      if (dark) {
        canvas.drawCircle(
          Offset(cx, tipY),
          radius - _outlineWidth / 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _outlineWidth
            ..color = _white.withValues(alpha: _outlineAlpha * opacity),
        );
      }
    } else if (shader case final shader?) {
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
        ..setFloat(11, blend)
        ..setFloat(12, _outlineWidth)
        ..setFloat(13, dark ? _outlineAlpha : 0);
      canvas.drawRect(bounds, Paint()..shader = shader);
    } else {
      final fill = Paint()..color = _black.withValues(alpha: opacity);
      var path = Path();
      if (island != null) {
        path.addRRect(
          RRect.fromRectAndRadius(island, Radius.circular(island.height / 2)),
        );
      }
      if (neck > 0) {
        path = Path.combine(
          PathOperation.union,
          path,
          Path()..addRRect(
            RRect.fromLTRBR(
              cx - neck,
              geometry.neckY - neck,
              cx + neck,
              tipY + neck,
              Radius.circular(neck),
            ),
          ),
        );
      }
      path = Path.combine(
        PathOperation.union,
        path,
        Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, tipY), radius: radius)),
      );
      canvas.drawPath(path, fill);
      if (dark) {
        canvas
          ..save()
          ..clipRect(
            Rect.fromLTRB(
              bounds.left,
              island?.bottom ?? geometry.edgeY,
              bounds.right,
              bounds.bottom,
            ),
          )
          ..clipPath(path)
          ..drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = _outlineWidth * 2
              ..color = _white.withValues(alpha: _outlineAlpha * opacity),
          )
          ..restore();
      }
    }
    final emergence = geometry.emergence(extension);
    if (emergence > 0) {
      _paintIndicator(canvas, Offset(cx, tipY), emergence, swell);
    }
  }

  void _paintBelowHeader(Canvas canvas, Size size, double extension) {
    const trigger = PrismRefreshLayerState.trigger;
    final progress = (extension / trigger).clamp(0.0, 1.0);
    final boundary = state.widget.headerBoundary?.value ?? Rect.zero;
    final center = Offset(
      boundary.width > 0 ? boundary.center.dx : size.width / 2,
      boundary.top + progress * PrismRefreshLayerState.compactExtent / 2,
    );
    final swell = state._swell.value.clamp(0.0, 1.4);
    final radius = _DropGeometry.radius + 2 * swell;

    canvas
      ..saveLayer(
        Rect.fromCircle(center: center, radius: radius + 3),
        Paint()..color = _white.withValues(alpha: progress),
      )
      ..translate(center.dx, center.dy)
      ..scale(progress)
      ..drawCircle(Offset.zero, radius, Paint()..color = _black);
    if (dark) {
      canvas.drawCircle(
        Offset.zero,
        radius - _outlineWidth / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _outlineWidth
          ..color = _white.withValues(alpha: _outlineAlpha),
      );
    }
    _paintIndicator(canvas, Offset.zero, 1, swell);
    canvas.restore();
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

    final breath = refreshing ? 0.0 : 0.05 * math.sin(time * 5.4) * swell;

    final bump = 0.16 * math.sin(math.pi * _interval(done, 0.2, 0.7));
    final scale = (1 + 0.14 * swell + breath + bump) * (0.7 + 0.3 * emergence);
    final radius = _ring * scale;
    final width = (_stroke + 0.5 * swell) * scale;
    final white = _white.withValues(alpha: emergence);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

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

    canvas.drawCircle(
      center,
      radius,
      stroke..color = _white.withValues(alpha: 0.2 * emergence),
    );

    final double tail;
    final double sweep;
    final double tailAlpha;
    if (!refreshing) {
      tail = -0.25;
      sweep = (state._pull.value / PrismRefreshLayerState.trigger).clamp(
        0.0,
        1.0,
      );
      tailAlpha = 1;
    } else {
      final close = Curves.easeOut.transform(_interval(done, 0, 0.28));
      final spin = 0.44 + 0.26 * math.sin(time * 2.7);
      sweep = ui.lerpDouble(ui.lerpDouble(1, spin, run), 1, close)!;
      tail = -0.25 + time * 1.2 - sweep;
      tailAlpha = ui.lerpDouble(ui.lerpDouble(1, 0.05, run), 1, close)!;
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
      old.shader != shader ||
      old.pixel != pixel ||
      old.dark != dark ||
      old.state != state;
}
