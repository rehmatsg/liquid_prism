import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/prism_glass.dart';
import '../core/prism_haptics.dart';
import '../core/prism_motion.dart';
import '../theme/prism_theme.dart';
import 'control_interaction.dart';
import 'control_material.dart';
import 'prism_slider_style.dart';

/// A parent-controlled slider with continuous endpoint fill blending.
class PrismSlider extends StatelessWidget {
  /// Creates a controlled slider over an inclusive numeric range.
  const PrismSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.label,
    this.semanticFormatterCallback,
    this.style,
  }) : assert(min <= max),
       assert(value >= min && value <= max),
       assert(divisions == null || divisions > 0);

  /// Parent-owned value and inclusive numeric range.
  final double value, min, max;

  /// Number of equal value divisions; null enables continuous input.
  final int? divisions;

  /// Value proposals and input-phase callbacks in the actual numeric range.
  final ValueChanged<double>? onChanged, onChangeStart, onChangeEnd;

  /// Accessible name for the slider.
  final String? label;

  /// Visual and motion overrides merged over the component theme.
  final PrismSliderStyle? style;

  /// Formats actual range values, including accessibility step previews.
  final String Function(double value)? semanticFormatterCallback;

  @override
  Widget build(BuildContext context) {
    final theme = PrismTheme.of(context);
    final appearance = (theme.slider ?? const PrismSliderStyle()).merge(style);
    final timing = (theme.controlMotion ?? const PrismControlMotion()).merge(
      appearance.motion,
    );
    final scale = appearance.scale ?? 1;
    final hitHeight = math.max(44.0, (appearance.hitHeight ?? 44) * scale);
    final trackHeight = (appearance.trackHeight ?? 6) * scale;
    final desiredThumb = (appearance.thumbSize ?? const Size(37, 24)) * scale;
    assert(desiredThumb.width > 0 && desiredThumb.height > 0);
    final heldScale = appearance.heldScale ?? 1.55;
    final colors = PrismTheme.colorsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final enabled = onChanged != null && max > min;
    final feedback = appearance.haptics ?? true;
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
                feedback &&
                    (theme.haptics != null ||
                        defaultTargetPlatform == TargetPlatform.iOS)
                ? () => dispatchPrismHaptic(
                    context,
                    const PrismHapticEvent(
                      PrismHapticComponent.slider,
                      PrismHapticKind.limitReached,
                    ),
                  )
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
            grabExtent: math.max(22.0, thumb.width * heldScale / 2),
            builder: (context, position, lift, stretch, activate) {
              final p = position.clamp(0.0, 1.0);
              final x = center + travel * (rtl ? 1 - p : p);
              final thumbWidth = thumb.width * (1 + (heldScale - 1) * lift),
                  thumbHeight = thumb.height * (1 + (heldScale - 1) * lift);
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
                        shape: appearance.trackShape ?? PrismShape.capsule,
                        color: appearance.inactiveColor ?? colors.sliderTrack,
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
                                    appearance.trackShape ?? PrismShape.capsule,
                                color:
                                    appearance.activeColor ??
                                    PrismTheme.tintOf(context),
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
                          color: appearance.thumbColor,
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
