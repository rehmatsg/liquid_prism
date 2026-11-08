import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'motion.dart';
import 'navigation_bar_style.dart';

void animateNavigationTitle({
  required AnimationController large,
  required AnimationController inline,
  required GlassNavigationBarStyle style,
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
    springGlass(
      inline,
      target,
      (collapsed
              ? style.revealSpring ?? GlassNavigationBarStyle.titleSpring
              : style.hideSpring ?? GlassNavigationBarStyle.titleHideSpring)
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
