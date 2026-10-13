import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'control_interaction.dart';
import 'control_material.dart';
import 'theme.dart';
import 'appearance.dart';
import 'motion.dart';
import 'material.dart';

/// A controlled slider with a native six-point track and a lifted capsule thumb.
/// [onChanged] reports drag updates. Null disables touch, keys and semantics.
/// Bounded parent constraints determine width; the intrinsic width is 300.
class LiquidPrismSlider extends StatelessWidget {
  const LiquidPrismSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.label,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.style,
    this.motion,
    this.semanticFormatterCallback,
    this.haptics,
  }) : assert(min <= max),
       assert(value >= min && value <= max),
       assert(divisions == null || divisions > 0);
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double>? onChanged, onChangeStart, onChangeEnd;
  final String? label;
  final Color? activeColor, inactiveColor, thumbColor;
  final GlassSliderStyle? style;
  final GlassControlMotion? motion;

  /// Format the actual numeric value for accessibility; default is percentage.
  final String Function(double value)? semanticFormatterCallback;

  /// A light impact on iOS when a drag, tap, key or accessibility step that
  /// the parent accepts reaches [min] or [max]. Overrides
  /// [GlassSliderStyle.haptics]; defaults on.
  final bool? haptics;

  @override
  Widget build(BuildContext context) {
    final theme = LiquidPrismTheme.of(context);
    final appearance = (theme.slider ?? const GlassSliderStyle()).merge(style);
    final timing = (theme.controlMotion ?? const GlassControlMotion()).merge(
      motion,
    );
    final scale = appearance.scale ?? 1;
    final hitHeight = math.max(44.0, (appearance.hitHeight ?? 44) * scale);
    final trackHeight = (appearance.trackHeight ?? 6) * scale;
    final desiredThumb = (appearance.thumbSize ?? const Size(37, 24)) * scale;
    assert(desiredThumb.width > 0 && desiredThumb.height > 0);
    final heldScale = appearance.heldScale ?? 1.55;
    final colors = GlassColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final enabled = onChanged != null && max > min;
    final feedback = haptics ?? appearance.haptics ?? true;
    double actual(double fraction) => min + fraction * (max - min);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.constrainWidth(
          (appearance.width ?? 300) * scale,
        );
        if (width <= 0) return const SizedBox.shrink();
        final thumb = desiredThumb * math.min(1, width / desiredThumb.width);
        final travel = width - thumb.width;
        final center = thumb.width / 2;
        return SizedBox(
          width: width,
          height: hitHeight,
          child: ControlInteraction(
            value: max == min ? 0 : (value - min) / (max - min),
            continuous: true,
            steps: divisions,
            travel: math.max(travel, .001),
            motion: timing,
            label: label,
            semanticFormatter: semanticFormatterCallback == null
                ? null
                : (v) => semanticFormatterCallback!(actual(v)),
            semanticValue:
                semanticFormatterCallback?.call(value) ??
                '${(((value - min) / (max == min ? 1 : max - min)) * 100).round()}%',
            onChanged: enabled ? (v) => onChanged!(actual(v)) : null,
            onChangeStart: onChangeStart == null
                ? null
                : (v) => onChangeStart!(actual(v)),
            onChangeEnd: onChangeEnd == null
                ? null
                : (v) => onChangeEnd!(actual(v)),
            onEdgeFeedback:
                feedback && defaultTargetPlatform == TargetPlatform.iOS
                ? () => unawaited(HapticFeedback.lightImpact())
                : null,
            positionAt: (x) =>
                (((rtl ? width - x : x) - center) / math.max(travel, .001))
                    .clamp(0.0, 1.0),
            spring: timing.travel?.description ?? NativeControl.sliderTravel,
            trackingSpring:
                timing.tracking?.description ?? NativeControl.sliderTracking,
            liftSpring: timing.lift?.description ?? NativeControl.smallLift,
            releaseSpring:
                timing.release?.description ?? NativeControl.smallRelease,
            hangTime: timing.minimumLiftDuration ?? Duration.zero,
            // The held thumb's half width, at least half a 44-point target.
            grabExtent: math.max(22.0, thumb.width * heldScale / 2),
            builder: (context, position, lift, stretch, activate) {
              final p = position.clamp(0.0, 1.0);
              final x = center + travel * (rtl ? 1 - p : p);
              final thumbWidth = thumb.width * (1 + (heldScale - 1) * lift),
                  thumbHeight = thumb.height * (1 + (heldScale - 1) * lift);
              // Native fill follows the thumb except at the first/last 2%,
              // where it blends continuously to proportional track progress.
              // Direct layer measurements: doc/native_slider_fill_spec.json.
              final edgeBlend =
                  ((.02 - p) / .02).clamp(0.0, 1.0) +
                  ((p - .98) / .02).clamp(0.0, 1.0);
              final centerFill = center + travel * p;
              final fill = centerFill + (width * p - centerFill) * edgeBlend;
              return ControlDisabled(
                enabled: enabled,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: (hitHeight - trackHeight) / 2,
                      width: width,
                      height: trackHeight,
                      child: ControlTrack(
                        shape: appearance.trackShape ?? GlassShape.capsule,
                        color:
                            inactiveColor ??
                            appearance.inactiveColor ??
                            colors.sliderTrack,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: rtl ? null : 0,
                              right: rtl ? 0 : null,
                              width: fill,
                              child: ControlTrack(
                                shape:
                                    appearance.trackShape ?? GlassShape.capsule,
                                color:
                                    activeColor ??
                                    appearance.activeColor ??
                                    LiquidPrismTheme.tintOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: x - thumbWidth / 2,
                      top: hitHeight / 2 - thumbHeight / 2,
                      width: thumbWidth,
                      height: thumbHeight,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(
                          1 + stretch,
                          1 - stretch,
                          1,
                        ),
                        child: ControlThumb(
                          restingShadow: true,
                          minifyUnderlay: false,
                          lift: lift,
                          color: thumbColor ?? appearance.thumbColor,
                          style: appearance.lens,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
