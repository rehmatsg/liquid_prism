import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/controls/control_gesture.dart';
import 'package:liquid_prism/src/controls/control_lens_motion.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';

/// Owns controlled input, cancellation, feedback, and spring momentum.
@internal
class ControlInteraction extends StatefulWidget {
  /// Creates the interaction owner for a controlled value.
  const new({
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
    this.onEdgeFeedback,
    this.steps,
    this.toggle = false,
    this.continuous = false,
    this.hangTime = Duration.zero,
    this.grabExtent,
    this.label,
    this.semanticValue,
    this.semanticFormatter,
    this.motion = const PrismControlMotion(),
  });

  /// Parent-owned normalized value.
  final double value;

  /// Physical travel distance in logical pixels.
  final double travel;

  /// Proposes a value; null disables all input.
  final ValueChanged<double>? onChanged;

  /// Called when user input starts.
  final ValueChanged<double>? onChangeStart;

  /// Called when user input ends.
  final ValueChanged<double>? onChangeEnd;

  /// Feedback when user input crosses a discrete selection boundary.
  final VoidCallback? onSelectionFeedback;

  /// Feedback when the parent accepts a newly proposed endpoint.
  final VoidCallback? onEdgeFeedback;

  /// Maps a local physical coordinate to a normalized value.
  final double Function(double x) positionAt;

  /// Builds control geometry from position, lift, stretch, and activation.
  final Widget Function(
    BuildContext,
    double position,
    double lift,
    double stretch,
    ValueChanged<double> activate,
  )
  builder;

  /// Spring for selection travel.
  final SpringDescription spring;

  /// Spring for tracking a drag.
  final SpringDescription trackingSpring;

  /// Spring for lifting the lens.
  final SpringDescription liftSpring;

  /// Spring for releasing the lens.
  final SpringDescription releaseSpring;

  /// Number of equal normalized value divisions.
  final int? steps;

  /// Whether input toggles the value.
  final bool toggle;

  /// Whether dragging continuously proposes values.
  final bool continuous;

  /// Minimum duration that a contact keeps the lens lifted.
  final Duration hangTime;

  /// Half-width of the active grab region; null claims every contact.
  final double? grabExtent;

  /// Accessible name for the control.
  final String? label;

  /// Formatted current value for accessibility.
  final String? semanticValue;

  /// Formats normalized accessibility step previews.
  final String Function(double)? semanticFormatter;

  /// Merged control motion overrides.
  final PrismControlMotion motion;

  /// Returns the normalized value under an inactive-part press.
  static double? pressedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ControlPress>()?.value;

  @override
  State<ControlInteraction> createState() => _ControlInteractionState();
}

class _ControlPress extends InheritedWidget {
  const new({required this.value, required super.child});
  final double? value;
  @override
  bool updateShouldNotify(_ControlPress oldWidget) => value != oldWidget.value;
}

class _ControlInteractionState extends State<ControlInteraction>
    with TickerProviderStateMixin {
  late final _position = RetargetablePrismSpring(vsync: this)
    ..value = widget.value;
  late final _lift = RetargetablePrismSpring(vsync: this);
  late final _deformation = RetargetablePrismSpring(vsync: this);
  SpringDescription get _shapeSpring =>
      widget.motion.flex?.description ?? ControlLensMotion.spring;
  late final _flex = ControlLensMotion((stretch, impulse) {
    if (mounted && _dragging && !_reduceMotion) {
      springPrism(
        _deformation,
        stretch,
        _shapeSpring,
        velocity: _deformation.velocity + impulse,
        precision: _deformationPrecision,
      );
    }
  }, settings: () => widget.motion);

  final _focus = FocusNode();
  Timer? _release;
  int? _pointer;
  bool _dragging = false;
  bool _reduceMotion = false;
  bool _rtl = false;
  bool _committing = false;
  double _downX = 0;
  double _downValue = 0;
  double _candidate = 0;
  double _feedbackValue = 0;
  double? _lastEmitted;
  bool _unliftPending = false;

  double? _edge;

  double? _proposedEdge;
  bool _proposalExpiry = false;
  static double? _edgeOf(double value) =>
      value <= 1e-9 ? 0 : (value >= 1 - 1e-9 ? 1 : null);

  bool _grabbed = true;

  double? _pressed;
  bool get _enabled => widget.onChanged != null;
  bool _grabs(double x) {
    final extent = widget.grabExtent;
    return extent == null ||
        (widget.positionAt(x) - widget.value).abs() * widget.travel <= extent;
  }

  void _press(double? value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  double _quantize(double value) {
    final bounded = value.clamp(0.0, 1.0);
    return widget.steps == null
        ? bounded
        : (bounded * widget.steps!).round() / widget.steps!;
  }

  void _animate(
    RetargetablePrismSpring controller,
    double target,
    SpringDescription spring,
  ) => springPrism(
    controller,
    target,
    spring,
    immediate: _reduceMotion,
    precision: identical(controller, _lift)
        ? _liftPrecision
        : identical(controller, _deformation)
        ? _deformationPrecision
        : null,
  );

  double _pixelRatio = 1;

  double? get _liftPrecision => PrismSettle.precision(
    alphaPerUnit: 1,
    pixelsPerUnit: _liftReach * _pixelRatio,
  );
  static const _liftReach = 24.0;

  double? get _deformationPrecision {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return PrismSettle.precision(
      pixelsPerUnit: (box.size.longestSide / 2 + _liftReach) * _pixelRatio,
    );
  }

  @override
  void initState() {
    super.initState();
    _edge = _edgeOf(widget.value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rtl = Directionality.of(context) == TextDirection.rtl;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
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
    if (widget.value != oldWidget.value) _settleEdge();
  }

  void _settleEdge() {
    final edge = _edgeOf(widget.value);
    final proposed = _proposedEdge;
    _proposedEdge = null;
    if (edge != null &&
        edge != _edge &&
        edge == proposed &&
        widget.continuous &&
        _enabled) {
      widget.onEdgeFeedback?.call();
    }
    _edge = edge;
  }

  void _proposeEdge(double value) {
    if (!widget.continuous || widget.onEdgeFeedback == null) return;
    _proposedEdge = _edgeOf(value);
    if (_proposalExpiry) return;
    _proposalExpiry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _proposalExpiry = false;
      _proposedEdge = null;
    });
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
    _grabbed = _grabs(_downX);
    if (_grabbed) {
      _raise();
    } else if (!widget.continuous) {
      _press(_quantize(widget.positionAt(_downX)));
    }
  }

  void _raise() {
    _release?.cancel();
    _unliftPending = false;
    if (!_reduceMotion && widget.hangTime > Duration.zero) {
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
    _flex.stop();
    _unlift();
  }

  void _cancel() {
    _proposedEdge = null;
    _flex.stop();
    final wasDragging = _dragging;
    _pointer = null;
    _dragging = false;
    _press(null);
    _animate(_deformation, 0, _shapeSpring);
    _release?.cancel();
    _unliftPending = false;
    _animate(_lift, 0, widget.releaseSpring);
    _animate(_position, widget.value, widget.spring);
    if (wasDragging) widget.onChangeEnd?.call(widget.value);
  }

  void _notify(double value) {
    _lastEmitted = _quantize(value);
    _proposeEdge(_lastEmitted!);
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
    _press(null);
    final travels = _quantize(next) != _quantize(widget.value);
    if (!_grabbed && travels && !widget.continuous) _raise();
    _activate(next);
    if (!_grabbed) _unlift();
  }

  void _dragStart(DragStartDetails details) {
    if (_pointer == null || !_enabled) return;
    _dragging = true;
    widget.onChangeStart?.call(widget.value);
    if (!_grabbed) {
      if (!widget.continuous) {
        _candidate = _quantize(widget.positionAt(details.localPosition.dx));
        _press(_candidate);
        return;
      }
      _grabbed = true;
      _downValue = widget.positionAt(_downX);
      _raise();
    }
    _flex.follow();
    _dragTo(details.localPosition.dx);
  }

  void _dragTo(double x) {
    if (!_grabbed) {
      _candidate = _quantize(widget.positionAt(x));
      _press(_candidate);
      return;
    }
    final delta = (x - _downX) / widget.travel * (_rtl ? -1 : 1);
    _candidate = (_downValue + delta).clamp(0.0, 1.0);
    final target = widget.continuous ? _quantize(_candidate) : _candidate;
    if (widget.continuous) {
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
    if (_pressed != null) {
      _press(null);
      if (target != _quantize(widget.value)) _raise();
    }
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
    _pressed = null;
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
            child: ControlGestureDetector(
              enabled: _enabled,
              claimsContact: widget.grabExtent == null
                  ? null
                  : (position) => _grabs(position.dx),
              onTapUp: _tap,
              onStart: _dragStart,
              onUpdate: (details) {
                if (_dragging) _dragTo(details.localPosition.dx);
              },
              onEnd: _dragEnd,
              onCancel: () {
                if (_pointer != null || _dragging) _cancel();
              },
              child: _ControlPress(
                value: _pressed,
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
      ),
    );
  }
}
