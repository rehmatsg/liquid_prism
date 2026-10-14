import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'motion.dart';
import 'theme.dart';

import 'package:flutter/widgets.dart';

/// Immediate feedback with a spring that preserves velocity on interruption.
/// Async actions do not lock the button; callers disable it while busy if needed.
class LiquidPrismPressable extends StatefulWidget {
  const LiquidPrismPressable({
    super.key,
    required this.child,
    required this.onPressed,
    required this.label,
    this.selected = false,
    this.motion,
  }) : _glass = false,
       _feedbackOnly = false;
  const LiquidPrismPressable.glass({
    super.key,
    required this.child,
    required this.onPressed,
    required this.label,
    this.selected = false,
    this.motion,
  }) : _glass = true,
       _feedbackOnly = false;

  /// Visual feedback only: leaves gesture recognition and semantics to the child.
  const LiquidPrismPressable.feedback({
    super.key,
    required this.child,
    this.motion,
  }) : onPressed = null,
       label = '',
       selected = false,
       _glass = true,
       _feedbackOnly = true;
  final Widget child;
  final FutureOr<void> Function()? onPressed;
  final String label;
  final bool selected;
  final GlassMotion? motion;
  final bool _glass, _feedbackOnly;
  @override
  State<LiquidPrismPressable> createState() => _LiquidPrismPressableState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'))
      ..add(
        ObjectFlagProperty<FutureOr<void> Function()>.has(
          'onPressed',
          onPressed,
        ),
      );
  }
}

class _LiquidPrismPressableState extends State<LiquidPrismPressable>
    with TickerProviderStateMixin {
  late final _press = AnimationController.unbounded(vsync: this, value: 0);
  // Glow is nonspatial: it reaches full strength within ~0.1 s of contact and
  // decays after release independently of the scale spring's bounce.
  late final _glow = AnimationController.unbounded(vsync: this, value: 0);
  bool _reduceMotion = false, _attached = true, _suppressTap = false;
  final _contacts = <int>{};
  int? _pointer;
  Offset? _downPosition;
  bool get _enabled => widget._feedbackOnly || widget.onPressed != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    if (_reduceMotion) {
      _press.value = _pointer == null || _suppressTap ? 0 : 1;
      _glow.value = _press.value;
    }
  }

  @override
  void didUpdateWidget(LiquidPrismPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled || widget._glass != oldWidget._glass) {
      _pointer = null;
      _downPosition = null;
      _suppressTap = true;
      _press.value = 0;
      _glow.value = 0;
    }
  }

  @override
  void deactivate() {
    _attached = false;
    _contacts.clear();
    _pointer = null;
    _downPosition = null;
    _suppressTap = true;
    _press.stop();
    _glow.stop();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _attached = true;
    _press.value = 0;
    _glow.value = 0;
  }

  void _target(bool held) {
    if (!_attached || !mounted) return;
    if (_reduceMotion) {
      _press.value = held ? 1 : 0;
      _glow.value = _press.value;
      return;
    }
    final motion =
        widget.motion ??
        LiquidPrismTheme.of(context).motion ??
        const GlassMotion();
    springGlass(
      _press,
      held ? 1 : 0,
      held ? motion.pressSpring : motion.releaseSpring,
      precision: _scalePrecision(motion),
    );
    springGlass(
      _glow,
      held ? 1 : 0,
      held ? NativeMotion.buttonGlowIn : NativeMotion.buttonGlowOut,
      precision: _glowPrecision,
    );
  }

  double _pixelRatio = 1;

  /// The press scales the surface about its centre, so a unit of press moves
  /// its farthest point (plus room for badges riding the corners) by the
  /// scale change times that distance.
  double? _scalePrecision(GlassMotion motion) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final reach = box.size.center(Offset.zero).distance + _badgeReach;
    final scale = (widget._glass ? motion.pressScale - 1 : .04).abs();
    return GlassSettle.precision(pixelsPerUnit: scale * reach * _pixelRatio);
  }

  static const _badgeReach = 16.0;

  /// Glow drives the press grade: at most [NativeMotion.buttonGlowOpacity]
  /// times the shader's 0.9 mix toward a graded colour at most 0.2 away per
  /// channel (gradePressed in glass_core.glsl), and the fallback's 0.08 white.
  static final _glowPrecision = GlassSettle.precision(
    alphaPerUnit: NativeMotion.buttonGlowOpacity * .9 * .2,
  );

  void _invoke() {
    if (_attached && mounted && widget.onPressed != null) widget.onPressed!();
  }

  void _down(PointerDownEvent event) {
    _contacts.add(event.pointer);
    if (!_enabled) {
      _suppressTap = true;
    }
    if (!_enabled || _pointer != null || _contacts.length != 1) return;
    _suppressTap = false;
    _pointer = event.pointer;
    _downPosition = event.position;
    _target(true);
  }

  void _release(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _contacts.remove(event.pointer);
    }
    if (_pointer != event.pointer) return;
    if (event is PointerCancelEvent || event is PointerMoveEvent) {
      _suppressTap = true;
    }
    _pointer = null;
    _downPosition = null;
    _target(false);
  }

  @override
  void dispose() {
    _press.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion =
        widget.motion ??
        LiquidPrismTheme.of(context).motion ??
        const GlassMotion();
    final visual = AnimatedBuilder(
      animation: Listenable.merge([_press, _glow]),
      builder: (context, child) {
        final scale = _reduceMotion
            ? 1.0
            : 1 + (widget._glass ? motion.pressScale - 1 : -.04) * _press.value;
        // Glass applies the scale itself: a scale above its backdrop filter
        // makes Impeller re-rasterize the captured backdrop every frame.
        if (widget._glass) {
          return LiquidPrismPressFeedback(
            progress: _glow.value.clamp(0, 1) * NativeMotion.buttonGlowOpacity,
            scale: scale,
            child: child!,
          );
        }
        return Transform.scale(
          scale: scale,
          child: LiquidPrismPressFeedback(progress: 0, child: child!),
        );
      },
      child: widget.child,
    );
    final listener = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: (event) {
        if (_pointer == event.pointer &&
            _downPosition != null &&
            (event.position - _downPosition!).distance > kTouchSlop) {
          _release(event);
        }
      },
      onPointerUp: _release,
      onPointerCancel: _release,
      child: widget._feedbackOnly
          ? visual
          : GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTapCancel: () {
                _suppressTap = true;
                _target(false);
              },
              onTap: !_enabled
                  ? null
                  : () {
                      if (!_suppressTap) _invoke();
                    },
              child: visual,
            ),
    );
    if (widget._feedbackOnly) return listener;
    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.selected,
      enabled: _enabled,
      onTap: _enabled ? _invoke : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _enabled,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _invoke();
              return null;
            },
          ),
        },
        child: listener,
      ),
    );
  }
}

/// Shared visual progress; internal to material and interaction composition.
@internal
class LiquidPrismPressFeedback extends InheritedWidget {
  const LiquidPrismPressFeedback({
    super.key,
    required this.progress,
    this.scale = 1,
    required super.child,
  });
  final double progress;

  /// Press scale for the nearest glass, which scales its own contour, shadow
  /// and content so the backdrop filter stays untransformed.
  final double scale;
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LiquidPrismPressFeedback>()
          ?.progress ??
      0;
  static double scaleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LiquidPrismPressFeedback>()
          ?.scale ??
      1;
  @override
  bool updateShouldNotify(LiquidPrismPressFeedback oldWidget) =>
      progress != oldWidget.progress || scale != oldWidget.scale;
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('progress', progress))
      ..add(DoubleProperty('scale', scale, defaultValue: 1));
  }
}
