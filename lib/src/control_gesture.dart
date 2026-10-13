import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// The single gesture owner of a tab bar, slider, switch or segmented control.
///
/// **Claimed contacts** (the default; see [claimsContact]) belong to the
/// control from touch-down. The recognizer resolves the arena on contact, so an
/// ancestor scroll view or page view cannot take a drag that begins there,
/// whatever its angle; this matches the measured iOS 27 slider thumb inside a
/// `ScrollView`. Movement past the platform touch slop in **any** direction
/// starts a drag. The control reads its own axis from each sample, so a
/// diagonal drag moves it by the along-axis component.
///
/// **Unclaimed contacts** (a slider track away from the thumb, an unselected
/// segment) compete like an axis-locked drag: they start a drag only once the
/// along-axis movement passes the slop, which an ancestor scrollable whose
/// own axis moved further first will win. Without such a competitor they still
/// belong to the control, and a mostly cross-axis movement simply ends in
/// nothing on release.
///
/// A release before any drag is a tap at the release point, unless an
/// unclaimed contact moved past the slop. Only the first contact is tracked;
/// the control handles additional contacts itself.
class ControlGestureRecognizer extends OneSequenceGestureRecognizer {
  ControlGestureRecognizer({super.debugOwner, super.supportedDevices});

  /// Main axis of the control; [DragEndDetails.primaryVelocity] uses it.
  Axis axis = Axis.horizontal;

  /// Whether a contact at this local position claims the pointer on contact.
  /// Null claims every contact.
  bool Function(Offset localPosition)? claimsContact;

  GestureDragStartCallback? onStart;
  GestureDragUpdateCallback? onUpdate;
  GestureDragEndCallback? onEnd;
  GestureTapUpCallback? onTapUp;

  /// The contact ended without a tap or drag end: lost arena, pointer cancel,
  /// or an unclaimed contact that moved off its axis and was released.
  VoidCallback? onCancel;

  int? _pointer;
  PointerDeviceKind _kind = PointerDeviceKind.touch;
  Offset _downGlobal = Offset.zero, _downLocal = Offset.zero;
  bool _claimed = true, _dragging = false, _movedOff = false;
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
    _velocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);
    _claimed = claimsContact?.call(event.localPosition) ?? true;
    // The arena is still open while the down event is dispatched, and this
    // recognizer sees it before ancestor scrollables, so a claim made here
    // makes the control the eager winner.
    if (_claimed) resolvePointer(event.pointer, GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
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
        // An unclaimed tap wins over competitors that have not claimed yet.
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
        // May report the rejection through [rejectGesture] first.
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

  /// Release velocity along the control's axis, zero unless it is a fling.
  /// Like an axis-locked drag, a fling needs the minimum speed and more than
  /// the slop of along-axis travel; travel counts from contact rather than
  /// over the estimator's last samples, so short fast flicks still project.
  /// The cross-axis share of a diagonal flick does not move a value.
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
    // An ancestor scrollable won an unclaimed contact.
    _cancel();
    _finish(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointer = null;
    _dragging = false;
    _velocity = null;
  }

  @override
  String get debugDescription => 'control';
}

/// Attaches one [ControlGestureRecognizer] to [child], or none when disabled
/// so pointers on a disabled control fall through to ancestor gestures.
class ControlGestureDetector extends StatelessWidget {
  const ControlGestureDetector({
    super.key,
    required this.enabled,
    required this.child,
    this.axis = Axis.horizontal,
    this.claimsContact,
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onTapUp,
    this.onCancel,
  });
  final bool enabled;
  final Axis axis;
  final bool Function(Offset localPosition)? claimsContact;
  final GestureDragStartCallback? onStart;
  final GestureDragUpdateCallback? onUpdate;
  final GestureDragEndCallback? onEnd;
  final GestureTapUpCallback? onTapUp;
  final VoidCallback? onCancel;
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
                  ..onCancel = onCancel,
              ),
      },
      child: child,
    );
  }
}
