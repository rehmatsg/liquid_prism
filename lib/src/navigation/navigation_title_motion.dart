import 'dart:async';

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/prism_motion.dart';
import 'prism_navigation_bar_style.dart';

@internal
void animateNavigationTitle({
  required AnimationController large,
  required AnimationController inline,
  required PrismNavigationBarStyle style,
  required bool collapsed,
  required bool immediate,
  required bool Function() isMounted,
}) {
  assert(
    style.largeTitleFadeDuration == null ||
        !style.largeTitleFadeDuration!.isNegative,
  );
  assert(style.inlineTitleDelay == null || !style.inlineTitleDelay!.isNegative);
  void animate() {
    if (!isMounted()) return;
    final target = collapsed ? 1.0 : 0.0;
    if (immediate) {
      large.value = inline.value = target;
      return;
    }
    large.stop();
    unawaited(
      large.animateTo(
        target,
        duration:
            style.largeTitleFadeDuration ?? const Duration(milliseconds: 200),
        curve: style.largeTitleFadeCurve ?? Curves.easeInOut,
      ),
    );
    springPrism(
      inline,
      target,
      (collapsed
              ? style.revealSpring ?? PrismNavigationBarStyle.titleSpring
              : style.hideSpring ?? PrismNavigationBarStyle.titleHideSpring)
          .description,
      precision: .005,
      delay: style.inlineTitleDelay ?? const Duration(milliseconds: 12),
    );
  }

  if ((immediate || style.largeTitleFadeDuration == Duration.zero) &&
      SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((_) => animate());
  } else {
    animate();
  }
}
