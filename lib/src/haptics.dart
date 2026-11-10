import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

enum GlassHapticComponent { tabBar, switchControl, slider, refresh }

enum GlassHapticKind {
  selectionChange,
  toggle,
  limitReached,
  longPress,

  /// Pull to refresh: the drop starts to leave its anchor.
  refreshPulled,

  /// Pull to refresh: the drop pinches off, so a release will refresh; also
  /// the start of a refresh begun from code.
  refreshArmed,

  /// Pull to refresh: the refresh completed.
  refreshSucceeded,

  /// Pull to refresh: the refresh reported a failure. Silent by default.
  refreshFailed,

  /// Pull to refresh: the user released an armed pull, starting the refresh.
  /// Not emitted for programmatic refreshes or pulls released below threshold.
  refreshReleased,
}

@immutable
final class GlassHapticEvent {
  const GlassHapticEvent(this.component, this.kind);
  final GlassHapticComponent component;
  final GlassHapticKind kind;
}

/// App feedback policy, invoked only at the component's existing boundaries.
@immutable
final class GlassHaptics {
  const GlassHaptics(this.onFeedback);
  final void Function(BuildContext context, GlassHapticEvent event) onFeedback;
}

/// Internal dispatch. Callers retain their enabled and platform gates.
void dispatchGlassHaptic(BuildContext context, GlassHapticEvent event) {
  final hook = LiquidPrismTheme.of(context).haptics;
  if (hook != null) {
    hook.onFeedback(context, event);
    return;
  }
  switch (event.kind) {
    case GlassHapticKind.selectionChange:
      unawaited(HapticFeedback.selectionClick());
    case GlassHapticKind.refreshArmed:
      unawaited(HapticFeedback.mediumImpact());
    case GlassHapticKind.refreshSucceeded:
      unawaited(HapticFeedback.successNotification());
    case GlassHapticKind.refreshFailed:
      break;
    case GlassHapticKind.toggle ||
        GlassHapticKind.limitReached ||
        GlassHapticKind.longPress ||
        GlassHapticKind.refreshPulled ||
        GlassHapticKind.refreshReleased:
      unawaited(HapticFeedback.lightImpact());
  }
}
