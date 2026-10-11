import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';

/// One interaction owner for the native small controls. Geometry stays in the
/// public widgets; this owns cancellation, controlled values and spring momentum.
class ControlInteraction extends StatefulWidget {
  const ControlInteraction({
    super.key,
    required this.value,
    required this.onChanged,
    required this.builder,
    required this.positionAt,
    required this.travel,
    required this.spring,
    required this.trackingSpring,
    required this.liftSpring,
    required this.releaseSpring,
    this.onChangeStart,
    this.onChangeEnd,
    this.steps,
    this.toggle = false,
    this.continuous = false,
    this.hangTime = Duration.zero,
    this.label,
    this.semanticValue,
  });
  final double value, travel;
  final ValueChanged<double>? onChanged, onChangeStart, onChangeEnd;
  final double Function(double x) positionAt;
  final Widget Function(
    BuildContext,
    double position,
    double lift,
    double stretch,
    ValueChanged<double> activate,
  )
  builder;
  final SpringDescription spring, trackingSpring, liftSpring, releaseSpring;
  final int? steps;
  final bool toggle, continuous;
  final Duration hangTime;
  final String? label, semanticValue;

  @override
  State<ControlInteraction> createState() => _ControlInteractionState();
}

class _ControlInteractionState extends State<ControlInteraction>
    with TickerProviderStateMixin {
  late final _position = RetargetableGlassSpring(vsync: this)
    ..value = widget.value;
  late final _lift = RetargetableGlassSpring(vsync: this);
  late final _deformation = RetargetableGlassSpring(vsync: this);
  static final _shapeSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 444),
    bounce: .44,
  );
  @override
  void initState() {
    super.initState();
    _position.addListener(_followVelocity);
  }

  void _followVelocity() {
    if (!_dragging || _reduceMotion) return;
    // The native small-loupe scale spring is exact; the velocity-to-scale
    // coupling is an approximation (see the extracted spec's limitations).
    final stretch = (_position.velocity * widget.travel * .00015).clamp(
      -.1,
      .1,
    );
    springGlass(_deformation, stretch, _shapeSpring);
  }

  final _focus = FocusNode();
  Timer? _release;
  int? _pointer;
  bool _dragging = false,
      _reduceMotion = false,
      _rtl = false,
      _committing = false;
  double _downX = 0, _downValue = 0, _candidate = 0;
  double? _lastEmitted;
  DateTime? _contactTime;
  bool get _enabled => widget.onChanged != null;
  double _quantize(double value) {
    final bounded = value.clamp(0.0, 1.0);
    return widget.steps == null
        ? bounded
        : (bounded * widget.steps!).round() / widget.steps!;
  }

  void _animate(
    RetargetableGlassSpring controller,
    double target,
    SpringDescription spring,
  ) => springGlass(controller, target, spring, immediate: _reduceMotion);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rtl = Directionality.of(context) == TextDirection.rtl;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_rtl != rtl || _reduceMotion) {
      _cancel();
      _position.value = widget.value;
      _lift.value = 0;
    }
    _rtl = rtl;
  }

  @override
  void didUpdateWidget(ControlInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled ||
        oldWidget.steps != widget.steps ||
        oldWidget.travel != widget.travel) {
      _cancel();
    }
    final acceptedDragUpdate =
        _dragging &&
        _lastEmitted != null &&
        (widget.value - _lastEmitted!).abs() < 1e-8;
    if (widget.value != oldWidget.value &&
        !_committing &&
        _pointer != null &&
        !acceptedDragUpdate) {
      _cancel();
    }
    if (!_dragging) _animate(_position, widget.value, widget.spring);
  }

  void _down(PointerDownEvent event) {
    if (!_enabled) return;
    if (_pointer != null) {
      _cancel();
      return;
    }
    _pointer = event.pointer;
    _contactTime = DateTime.now();
    _downX = event.localPosition.dx;
    _downValue = _position.value;
    _candidate = widget.value;
    _focus.requestFocus();
    _release?.cancel();
    _animate(_lift, 1, widget.liftSpring);
  }

  void _unlift() {
    _release?.cancel();
    final elapsed = DateTime.now().difference(_contactTime ?? DateTime.now());
    final remaining = widget.hangTime - elapsed;
    if (!_reduceMotion && remaining > Duration.zero) {
      _release = Timer(
        remaining,
        () => _animate(_lift, 0, widget.releaseSpring),
      );
    } else {
      _animate(_lift, 0, widget.releaseSpring);
    }
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    // Gesture recognizers deliver tap/drag completion after the raw event.
    _unlift();
  }

  void _cancel() {
    final wasDragging = _dragging;
    _pointer = null;
    _dragging = false;
    _animate(_deformation, 0, _shapeSpring);
    _release?.cancel();
    _animate(_lift, 0, widget.releaseSpring);
    _animate(_position, widget.value, widget.spring);
    if (wasDragging) widget.onChangeEnd?.call(widget.value);
  }

  void _notify(double value) {
    _lastEmitted = _quantize(value);
    _committing = true;
    try {
      widget.onChanged?.call(_quantize(value));
    } finally {
      _committing = false;
    }
  }

  void _settle() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_dragging) {
        _animate(_position, widget.value, widget.spring);
      }
    });
  }

  void _activate(double value) {
    if (!_enabled) return;
    final target = _quantize(value);
    widget.onChangeStart?.call(widget.value);
    _animate(_position, target, widget.spring);
    _notify(target);
    widget.onChangeEnd?.call(target);
    _settle();
  }

  void _tap(TapUpDetails details) {
    if (_pointer == null || !_enabled) return;
    final next = widget.toggle
        ? 1 - widget.value
        : widget.positionAt(details.localPosition.dx);
    _pointer = null;
    _activate(next);
  }

  void _dragStart(DragStartDetails details) {
    if (_pointer == null || !_enabled) return;
    _dragging = true;
    widget.onChangeStart?.call(widget.value);
    // Slider track taps jump to the contact; a thumb grab preserves its offset.
    if (widget.continuous &&
        (widget.positionAt(_downX) - _downValue).abs() * widget.travel > 28.7) {
      _downValue = widget.positionAt(_downX);
    }
    _dragTo(details.localPosition.dx);
  }

  void _dragTo(double x) {
    final delta = (x - _downX) / widget.travel * (_rtl ? -1 : 1);
    _candidate = (_downValue + delta).clamp(0.0, 1.0);
    final target = widget.continuous ? _quantize(_candidate) : _candidate;
    _animate(_position, target, widget.trackingSpring);
    if (widget.continuous) _notify(target);
  }

  void _dragEnd(DragEndDetails details) {
    if (!_dragging || !_enabled) return;
    _dragging = false;
    _animate(_deformation, 0, _shapeSpring);
    _pointer = null;
    final target = _quantize(_candidate);
    if (!widget.continuous) _notify(target);
    widget.onChangeEnd?.call(target);
    _animate(_position, target, widget.spring);
    _unlift();
    _settle();
  }

  @override
  void deactivate() {
    _release?.cancel();
    _pointer = null;
    _dragging = false;
    _position.stop();
    _lift.stop();
    _deformation.stop();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _position.value = widget.value;
    _lift.value = 0;
    _deformation.value = 0;
  }

  @override
  void dispose() {
    _release?.cancel();
    _focus.dispose();
    _position.dispose();
    _lift.dispose();
    _deformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = 1 / (widget.steps ?? 20);
    void advance(double delta) => _activate(widget.value + delta);
    return Semantics(
      enabled: _enabled,
      label: widget.label,
      toggled: widget.toggle ? widget.value == 1 : null,
      slider: widget.continuous,
      value: widget.semanticValue,
      increasedValue: widget.continuous
          ? '${((widget.value + step).clamp(0, 1) * 100).round()}%'
          : null,
      decreasedValue: widget.continuous
          ? '${((widget.value - step).clamp(0, 1) * 100).round()}%'
          : null,
      onIncrease: widget.continuous && _enabled ? () => advance(step) : null,
      onDecrease: widget.continuous && _enabled ? () => advance(-step) : null,
      onTap: widget.toggle && _enabled
          ? () => _activate(1 - widget.value)
          : null,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              advance(_rtl ? -step : step),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              advance(_rtl ? step : -step),
          const SingleActivator(LogicalKeyboardKey.home): () => _activate(0),
          const SingleActivator(LogicalKeyboardKey.end): () => _activate(1),
          const SingleActivator(LogicalKeyboardKey.space): () =>
              _activate(widget.toggle ? 1 - widget.value : widget.value),
          const SingleActivator(LogicalKeyboardKey.enter): () =>
              _activate(widget.toggle ? 1 - widget.value : widget.value),
        },
        child: Focus(
          focusNode: _focus,
          canRequestFocus: _enabled,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerUp: _up,
            onPointerCancel: (event) {
              if (event.pointer == _pointer) _cancel();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onTapUp: _enabled ? _tap : null,
              onTapCancel: () {
                scheduleMicrotask(() {
                  if (mounted && !_dragging && _pointer != null) _cancel();
                });
              },
              onHorizontalDragStart: _enabled ? _dragStart : null,
              onHorizontalDragUpdate: _enabled
                  ? (details) {
                      if (_dragging) _dragTo(details.localPosition.dx);
                    }
                  : null,
              onHorizontalDragEnd: _enabled ? _dragEnd : null,
              onHorizontalDragCancel: () {
                if (_dragging) _cancel();
              },
              child: AnimatedBuilder(
                animation: Listenable.merge([_position, _lift, _deformation]),
                builder: (context, _) => widget.builder(
                  context,
                  _position.value,
                  _reduceMotion ? 0 : _lift.value,
                  _reduceMotion ? 0 : _deformation.value,
                  _activate,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
