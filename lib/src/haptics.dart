import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

enum GlassHapticComponent { tabBar, switchControl, slider }

enum GlassHapticKind { selectionChange, toggle, limitReached, longPress }

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
  if (event.kind == GlassHapticKind.selectionChange) {
    unawaited(HapticFeedback.selectionClick());
  } else {
    unawaited(HapticFeedback.lightImpact());
  }
}
