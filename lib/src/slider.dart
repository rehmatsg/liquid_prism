import 'package:flutter/widgets.dart';

import 'control_interaction.dart';
import 'control_material.dart';
import 'theme.dart';

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
  }) : assert(min <= max),
       assert(value >= min && value <= max),
       assert(divisions == null || divisions > 0);
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double>? onChanged, onChangeStart, onChangeEnd;
  final String? label;
  final Color? activeColor, inactiveColor, thumbColor;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final enabled = onChanged != null && max > min;
    double actual(double fraction) => min + fraction * (max - min);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints
            .constrainWidth(300)
            .clamp(58.0, double.infinity);
        final travel = width - 37;
        return SizedBox(
          width: width,
          height: 44,
          child: ControlInteraction(
            value: max == min ? 0 : (value - min) / (max - min),
            continuous: true,
            steps: divisions,
            travel: travel,
            label: label,
            semanticValue:
                '${(((value - min) / (max == min ? 1 : max - min)) * 100).round()}%',
            onChanged: enabled ? (v) => onChanged!(actual(v)) : null,
            onChangeStart: onChangeStart == null
                ? null
                : (v) => onChangeStart!(actual(v)),
            onChangeEnd: onChangeEnd == null
                ? null
                : (v) => onChangeEnd!(actual(v)),
            positionAt: (x) =>
                (((rtl ? width - x : x) - 18.5) / travel).clamp(0.0, 1.0),
            spring: NativeControl.sliderTravel,
            trackingSpring: NativeControl.sliderTracking,
            liftSpring: NativeControl.smallLift,
            releaseSpring: NativeControl.smallRelease,
            builder: (context, position, lift, stretch, activate) {
              final p = position.clamp(0.0, 1.0);
              final x = 18.5 + travel * (rtl ? 1 - p : p);
              final thumbWidth = 37 * (1 + .55 * lift),
                  thumbHeight = 24 * (1 + .55 * lift);
              // Native fill follows the thumb except at the first/last 2%,
              // where it blends continuously to proportional track progress.
              // Direct layer measurements: doc/native_slider_fill_spec.json.
              final edgeBlend =
                  ((.02 - p) / .02).clamp(0.0, 1.0) +
                  ((p - .98) / .02).clamp(0.0, 1.0);
              final centerFill = 18.5 + travel * p;
              final fill = centerFill + (width * p - centerFill) * edgeBlend;
              return ControlDisabled(
                enabled: enabled,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: 19,
                      width: width,
                      height: 6,
                      child: ControlTrack(
                        color: inactiveColor ?? colors.sliderTrack,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: rtl ? null : 0,
                              right: rtl ? 0 : null,
                              width: fill,
                              child: ControlTrack(
                                color:
                                    activeColor ??
                                    LiquidPrismTheme.tintOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: x - thumbWidth / 2,
                      top: 22 - thumbHeight / 2,
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
                          color: thumbColor,
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
