import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'control_lens_motion.dart';
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
    this.onSelectionFeedback,
    this.steps,
    this.toggle = false,
    this.continuous = false,
    this.hangTime = Duration.zero,
    this.label,
    this.semanticValue,
    this.semanticFormatter,
    this.motion = const GlassControlMotion(),
  });
  final double value, travel;
  final ValueChanged<double>? onChanged, onChangeStart, onChangeEnd;
  final VoidCallback? onSelectionFeedback;
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
  final String Function(double)? semanticFormatter;
  final GlassControlMotion motion;

  @override
  State<ControlInteraction> createState() => _ControlInteractionState();
}

class _ControlInteractionState extends State<ControlInteraction>
    with TickerProviderStateMixin {
  late final _position = RetargetableGlassSpring(vsync: this)
    ..value = widget.value;
  late final _lift = RetargetableGlassSpring(vsync: this);
  late final _deformation = RetargetableGlassSpring(vsync: this);
  SpringDescription get _shapeSpring =>
      widget.motion.flex?.description ?? ControlLensMotion.spring;
  late final _flex = ControlLensMotion((stretch, impulse) {
    if (mounted && _dragging && !_reduceMotion) {
      springGlass(
        _deformation,
        stretch,
        _shapeSpring,
        velocity: _deformation.velocity + impulse,
      );
    }
  }, settings: () => widget.motion);

  final _focus = FocusNode();
  Timer? _release;
  int? _pointer;
  bool _dragging = false,
      _reduceMotion = false,
      _rtl = false,
      _committing = false;
  double _downX = 0, _downValue = 0, _candidate = 0;
  double _feedbackValue = 0;
  double? _lastEmitted;
  bool _unliftPending = false;
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
    _flex.begin(event);
    _downX = event.localPosition.dx;
    _downValue = _position.value;
    _candidate = widget.value;
    _feedbackValue = widget.value;
    _focus.requestFocus();
    _release?.cancel();
    _unliftPending = false;
    if (!_reduceMotion && widget.hangTime > Duration.zero) {
      // Count the minimum lift from contact with a timer, so long holds have
      // already consumed it. Recontact starts a fresh window. This uses the
      // same clock as cancellation and works with Flutter's test scheduler.
      _release = Timer(widget.hangTime, () {
        _release = null;
        if (_unliftPending && mounted) {
          _unliftPending = false;
          _animate(_lift, 0, widget.releaseSpring);
        }
      });
    }
    _animate(_lift, 1, widget.liftSpring);
  }

  void _unlift() {
    if (!_reduceMotion && (_release?.isActive ?? false)) {
      _unliftPending = true;
    } else {
      _unliftPending = false;
      _animate(_lift, 0, widget.releaseSpring);
    }
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    // Gesture recognizers deliver tap/drag completion after the raw event.
    _flex.stop();
    _unlift();
  }

  void _cancel() {
    _flex.stop();
    final wasDragging = _dragging;
    _pointer = null;
    _dragging = false;
    _animate(_deformation, 0, _shapeSpring);
    _release?.cancel();
    _unliftPending = false;
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

  void _selectionFeedback(double value) {
    if (widget.onSelectionFeedback == null) return;
    final target = _quantize(value);
    if (target == _feedbackValue) return;
    _feedbackValue = target;
    widget.onSelectionFeedback!();
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
    _feedbackValue = widget.value;
    _selectionFeedback(target);
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
    _flex.follow();
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
    if (widget.continuous) {
      // A grabbed slider follows the contact on the next frame. The captured
      // spring constructor describes animation, not a delay on every sample.
      // Taps, external updates and release still use the native travel spring.
      _position.value = target;
    } else {
      _animate(_position, target, widget.trackingSpring);
    }
    _selectionFeedback(_candidate);
    if (widget.continuous) _notify(target);
  }

  void _dragEnd(DragEndDetails details) {
    if (!_dragging || !_enabled) return;
    _dragging = false;
    _flex.stop();
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
    _flex.stop();
    _release?.cancel();
    _unliftPending = false;
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
    _flex.stop();
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
          ? widget.semanticFormatter?.call(_quantize(widget.value + step)) ??
                '${((widget.value + step).clamp(0, 1) * 100).round()}%'
          : null,
      decreasedValue: widget.continuous
          ? widget.semanticFormatter?.call(_quantize(widget.value - step)) ??
                '${((widget.value - step).clamp(0, 1) * 100).round()}%'
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
            onPointerMove: (event) {
              if (event.pointer == _pointer) {
                _flex.sample(event, active: _dragging && !_reduceMotion);
              }
            },
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
