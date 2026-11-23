import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// The gesture owner for a control and its scroll-arena arbitration.
@internal
class ControlGestureRecognizer extends OneSequenceGestureRecognizer {
  /// Creates the shared control gesture recognizer.
  new({super.debugOwner, super.supportedDevices});

  /// Main axis used to map drag velocity.
  Axis axis = Axis.horizontal;

  /// Whether contact immediately claims the gesture arena.
  bool Function(Offset localPosition)? claimsContact;

  /// Called when a drag begins.
  GestureDragStartCallback? onStart;

  /// Called for drag position updates.
  GestureDragUpdateCallback? onUpdate;

  /// Called when a drag ends.
  GestureDragEndCallback? onEnd;

  /// Called when contact resolves as a tap.
  GestureTapUpCallback? onTapUp;

  /// Called for a recognized long press.
  GestureLongPressStartCallback? onLongPress;
  Timer? _longPressTimer;
  bool _longPressed = false;

  /// Called when the current interaction is cancelled.
  VoidCallback? onCancel;

  int? _pointer;
  PointerDeviceKind _kind = PointerDeviceKind.touch;
  Offset _downGlobal = Offset.zero;
  Offset _downLocal = Offset.zero;
  bool _claimed = true;
  bool _dragging = false;
  bool _movedOff = false;
  VelocityTracker? _velocity;

  double get _slop => computeHitSlop(_kind, gestureSettings);
  double _along(Offset offset) =>
      axis == Axis.horizontal ? offset.dx : offset.dy;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _pointer == null && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointer = event.pointer;
    _kind = event.kind;
    _downGlobal = event.position;
    _downLocal = event.localPosition;
    _dragging = false;
    _movedOff = false;
    _longPressed = false;
    _velocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);
    _claimed = claimsContact?.call(event.localPosition) ?? true;
    if (_claimed) resolvePointer(event.pointer, GestureDisposition.accepted);
    if (onLongPress != null) {
      _longPressTimer = Timer(kLongPressTimeout, () {
        final callback = onLongPress;
        if (_pointer == null || _dragging || _movedOff || callback == null) {
          return;
        }
        resolvePointer(event.pointer, GestureDisposition.accepted);
        if (_pointer == null) return;
        _longPressed = true;
        invokeCallback<void>(
          'onLongPress',
          () => callback(
            LongPressStartDetails(
              globalPosition: _downGlobal,
              localPosition: _downLocal,
            ),
          ),
        );
      });
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (_longPressed) {
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        _finish(event.pointer);
      }
      return;
    }
    if (event is PointerMoveEvent) {
      if ((event.position - _downGlobal).distance > _slop) {
        _longPressTimer?.cancel();
      }
      if (!event.synthesized) {
        _velocity?.addPosition(event.timeStamp, event.localPosition);
      }
      if (!_dragging && !_startDrag(event)) return;
      final update = onUpdate;
      if (update != null) {
        invokeCallback<void>(
          'onUpdate',
          () => update(
            DragUpdateDetails(
              sourceTimeStamp: event.timeStamp,
              delta: event.localDelta,
              globalPosition: event.position,
              localPosition: event.localPosition,
            ),
          ),
        );
      }
    } else if (event is PointerUpEvent) {
      if (_dragging) {
        _end(event);
      } else if (!_movedOff) {
        if (!_claimed) {
          resolvePointer(event.pointer, GestureDisposition.accepted);
        }
        final tap = onTapUp;
        if (tap != null) {
          invokeCallback<void>(
            'onTapUp',
            () => tap(
              TapUpDetails(
                kind: _kind,
                globalPosition: event.position,
                localPosition: event.localPosition,
              ),
            ),
          );
        }
      } else {
        resolvePointer(event.pointer, GestureDisposition.rejected);
        _cancel();
      }
      _finish(event.pointer);
    } else if (event is PointerCancelEvent) {
      _cancel();
      _finish(event.pointer);
    }
  }

  bool _startDrag(PointerMoveEvent event) {
    final slop = _slop;
    final moved = (event.position - _downGlobal).distance > slop;
    if (_claimed) {
      if (!moved) return false;
    } else {
      if (_along(event.localPosition - _downLocal).abs() <= slop) {
        if (moved) _movedOff = true;
        return false;
      }
      resolvePointer(event.pointer, GestureDisposition.accepted);
      if (_pointer == null) return false;
    }
    _longPressTimer?.cancel();
    _dragging = true;
    final start = onStart;
    if (start != null) {
      invokeCallback<void>(
        'onStart',
        () => start(
          DragStartDetails(
            sourceTimeStamp: event.timeStamp,
            globalPosition: event.position,
            localPosition: event.localPosition,
            kind: _kind,
          ),
        ),
      );
    }
    return true;
  }

  void _end(PointerUpEvent event) {
    final end = onEnd;
    if (end == null) return;
    final velocity = _flingVelocity(event.localPosition);
    invokeCallback<void>(
      'onEnd',
      () => end(
        DragEndDetails(
          velocity: velocity,
          primaryVelocity: _along(velocity.pixelsPerSecond),
          globalPosition: event.position,
          localPosition: event.localPosition,
        ),
      ),
    );
  }

  Velocity _flingVelocity(Offset release) {
    final estimate = _velocity?.getVelocityEstimate();
    if (estimate == null) return Velocity.zero;
    final speed = _along(estimate.pixelsPerSecond);
    if (speed.abs() <= kMinFlingVelocity ||
        _along(release - _downLocal).abs() <= _slop) {
      return Velocity.zero;
    }
    return Velocity(
      pixelsPerSecond: axis == Axis.horizontal
          ? Offset(speed, 0)
          : Offset(0, speed),
    ).clampMagnitude(kMinFlingVelocity, kMaxFlingVelocity);
  }

  void _cancel() {
    final cancel = onCancel;
    if (_pointer != null && cancel != null) {
      invokeCallback<void>('onCancel', cancel);
    }
  }

  void _finish(int pointer) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _pointer = null;
    _dragging = false;
    _velocity = null;
    stopTrackingPointer(pointer);
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    if (pointer != _pointer) return;
    _cancel();
    _finish(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _pointer = null;
    _dragging = false;
    _velocity = null;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  String get debugDescription => 'control';
}

/// Connects a control to its single gesture recognizer.
@internal
class ControlGestureDetector extends StatelessWidget {
  /// Creates the single gesture owner for a control.
  const new({
    super.key,
    required this.enabled,
    required this.child,
    this.axis = Axis.horizontal,
    this.claimsContact,
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onTapUp,
    this.onLongPress,
    this.onCancel,
  });

  /// Whether the control participates in gesture recognition.
  final bool enabled;

  /// Main axis of the control.
  final Axis axis;

  /// Whether contact grabs the active selection immediately.
  final bool Function(Offset localPosition)? claimsContact;

  /// Called when a drag begins.
  final GestureDragStartCallback? onStart;

  /// Called for drag position updates.
  final GestureDragUpdateCallback? onUpdate;

  /// Called when a drag ends.
  final GestureDragEndCallback? onEnd;

  /// Called when contact resolves as a tap.
  final GestureTapUpCallback? onTapUp;

  /// Called for a recognized long press.
  final GestureLongPressStartCallback? onLongPress;

  /// Called when the current interaction is cancelled.
  final VoidCallback? onCancel;

  /// Control content receiving the gesture stream.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = MediaQuery.maybeGestureSettingsOf(context);
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      gestures: {
        if (enabled)
          ControlGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<ControlGestureRecognizer>(
                () => ControlGestureRecognizer(debugOwner: this),
                (recognizer) => recognizer
                  ..axis = axis
                  ..gestureSettings = settings
                  ..claimsContact = claimsContact
                  ..onStart = onStart
                  ..onUpdate = onUpdate
                  ..onEnd = onEnd
                  ..onTapUp = onTapUp
                  ..onLongPress = onLongPress
                  ..onCancel = onCancel,
              ),
      },
      child: child,
    );
  }
}
