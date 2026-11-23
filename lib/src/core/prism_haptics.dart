import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/theme/prism_theme.dart';

/// Component that emitted a haptic event.
enum PrismHapticComponent {
  /// A tab bar selection control.
  tabBar,

  /// A toggle switch.
  switchControl,

  /// A continuous slider control.
  slider,

  /// A pull-to-refresh control.
  refresh,

  /// An action button.
  button,
}

/// Semantic kind of haptic feedback event.
enum PrismHapticKind {
  /// A selection changed.
  selectionChange,

  /// A switch toggled.
  toggle,

  /// A control reached its limit.
  limitReached,

  /// A long press was recognized.
  longPress,

  /// A refresh pull began.
  refreshPulled,

  /// A refresh pull crossed the activation threshold.
  refreshArmed,

  /// A refresh completed successfully.
  refreshSucceeded,

  /// A refresh failed.
  refreshFailed,

  /// A refresh pull was released.
  refreshReleased,
}

/// Payload delivered to [PrismHaptics] callbacks.
@immutable
final class PrismHapticEvent {
  /// Creates a haptic event for [component] and [kind].
  const new(this.component, this.kind);

  /// Originating component.
  final PrismHapticComponent component;

  /// Interaction boundary kind.
  final PrismHapticKind kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismHapticEvent &&
          other.component == component &&
          other.kind == kind;

  @override
  int get hashCode => Object.hash(component, kind);
}

/// Custom app-level haptic feedback policy.
@immutable
final class PrismHaptics {
  /// Creates a haptic feedback handler.
  const new(this.onFeedback);

  /// Callback invoked when a component crosses a haptic boundary.
  final void Function(BuildContext context, PrismHapticEvent event) onFeedback;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismHaptics && other.onFeedback == onFeedback;

  @override
  int get hashCode => onFeedback.hashCode;
}

@internal
void dispatchPrismHaptic(BuildContext context, PrismHapticEvent event) {
  final hook = PrismTheme.of(context).haptics;
  if (hook != null) {
    hook.onFeedback(context, event);
    return;
  }
  switch (event.kind) {
    case PrismHapticKind.selectionChange:
      unawaited(HapticFeedback.selectionClick());
    case PrismHapticKind.refreshArmed:
      unawaited(HapticFeedback.mediumImpact());
    case PrismHapticKind.refreshSucceeded:
      unawaited(HapticFeedback.successNotification());
    case PrismHapticKind.refreshFailed:
      break;
    case PrismHapticKind.toggle ||
        PrismHapticKind.limitReached ||
        PrismHapticKind.longPress ||
        PrismHapticKind.refreshPulled ||
        PrismHapticKind.refreshReleased:
      unawaited(HapticFeedback.lightImpact());
  }
}
