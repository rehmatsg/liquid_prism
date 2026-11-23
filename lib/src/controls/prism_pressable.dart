import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// Interactive press wrapper with velocity-preserving spring feedback.
class PrismPressable extends StatefulWidget {
  /// Creates a pressable control that scales its child directly.
  const new({
    super.key,
    required this.child,
    required this.onPressed,
    required this.label,
    this.onLongPress,
    this.selected = false,
    this.motion,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.mouseCursor,
  }) : _glass = false,
       _feedbackOnly = false;

  /// Creates a pressable that publishes scale and glow to descendant glass.
  const new glass({
    super.key,
    required this.child,
    required this.onPressed,
    required this.label,
    this.onLongPress,
    this.selected = false,
    this.motion,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.mouseCursor,
  }) : _glass = true,
       _feedbackOnly = false;

  /// Creates a visual-only feedback wrapper that leaves gestures to its child.
  const new feedback({super.key, required this.child, this.motion})
    : onPressed = null,
      onLongPress = null,
      label = '',
      selected = false,
      focusNode = null,
      autofocus = false,
      onFocusChange = null,
      mouseCursor = null,
      _glass = true,
      _feedbackOnly = true;

  /// Content wrapped by this pressable control.
  final Widget child;

  /// Callback invoked on tap or keyboard activation; null disables activation.
  final FutureOr<void> Function()? onPressed;

  /// Callback invoked on long press when enabled.
  final VoidCallback? onLongPress;

  /// Accessible button label.
  final String label;

  /// Whether this control reports selected semantics.
  final bool selected;

  /// Optional press and release spring motion override.
  final PrismMotion? motion;

  /// Optional focus node for keyboard focus.
  final FocusNode? focusNode;

  /// Whether this control requests focus on mount.
  final bool autofocus;

  /// Called when keyboard focus changes.
  final ValueChanged<bool>? onFocusChange;

  /// Optional pointer cursor override.
  final MouseCursor? mouseCursor;

  final bool _glass;
  final bool _feedbackOnly;

  @override
  State<PrismPressable> createState() => _PrismPressableState();

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

class _PrismPressableState extends State<PrismPressable>
    with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  late final AnimationController _glow = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  bool _reduceMotion = false;
  bool _attached = true;
  bool _suppressTap = false;
  final Set<int> _contacts = <int>{};
  int? _pointer;
  Offset? _downPosition;
  double _pixelRatio = 1;

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
  void didUpdateWidget(PrismPressable oldWidget) {
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
        widget.motion ?? PrismTheme.of(context).motion ?? const PrismMotion();
    springPrism(
      _press,
      held ? 1 : 0,
      held ? motion.pressSpring : motion.releaseSpring,
      precision: _scalePrecision(motion),
    );
    springPrism(
      _glow,
      held ? 1 : 0,
      held ? NativeMotion.buttonGlowIn : NativeMotion.buttonGlowOut,
      precision: _glowPrecision,
    );
  }

  double? _scalePrecision(PrismMotion motion) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final reach = box.size.center(Offset.zero).distance + _badgeReach;
    final scale = (widget._glass ? motion.pressScale - 1 : .04).abs();
    return PrismSettle.precision(pixelsPerUnit: scale * reach * _pixelRatio);
  }

  static const double _badgeReach = 16;

  static final double? _glowPrecision = PrismSettle.precision(
    alphaPerUnit: NativeMotion.buttonGlowOpacity * .9 * .2,
  );

  void _longPress() {
    _suppressTap = true;
    if (_attached && mounted) widget.onLongPress?.call();
  }

  void _invoke() {
    if (_attached && mounted && widget.onPressed != null) {
      unawaited(Future<void>.value(widget.onPressed!()));
    }
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
        widget.motion ?? PrismTheme.of(context).motion ?? const PrismMotion();
    final visual = AnimatedBuilder(
      animation: Listenable.merge([_press, _glow]),
      builder: (context, child) {
        final scale = _reduceMotion
            ? 1.0
            : 1 + (widget._glass ? motion.pressScale - 1 : -.04) * _press.value;
        if (widget._glass) {
          return PrismPressFeedback(
            progress: _glow.value.clamp(0, 1) * NativeMotion.buttonGlowOpacity,
            scale: scale,
            child: child!,
          );
        }
        return Transform.scale(
          scale: scale,
          child: PrismPressFeedback(progress: 0, child: child!),
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
              onLongPress: !_enabled || widget.onLongPress == null
                  ? null
                  : _longPress,
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
      onLongPress: _enabled && widget.onLongPress != null ? _longPress : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: widget.onFocusChange,
        mouseCursor: widget.mouseCursor ?? MouseCursor.defer,
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

@internal
class PrismPressFeedback extends InheritedWidget {
  const new({
    super.key,
    required this.progress,
    required super.child,
    this.scale = 1,
  });

  final double progress;
  final double scale;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PrismPressFeedback>()
          ?.progress ??
      0;

  static double scaleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrismPressFeedback>()?.scale ??
      1;

  @override
  bool updateShouldNotify(PrismPressFeedback oldWidget) =>
      progress != oldWidget.progress || scale != oldWidget.scale;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('progress', progress))
      ..add(DoubleProperty('scale', scale, defaultValue: 1));
  }
}
