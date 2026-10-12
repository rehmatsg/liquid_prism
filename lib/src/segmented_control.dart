import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'control_interaction.dart';
import 'control_material.dart';
import 'theme.dart';
import 'appearance.dart';
import 'motion.dart';
import 'material.dart';

/// Equal-width segmented tabs, with a free-sliding glass selection lens.
/// Values follow the map's insertion order. The parent's [selectedValue] is
/// authoritative. Touch commits on release; keys and accessibility commit at once.
class LiquidPrismSegmentedControl<T extends Object> extends StatelessWidget {
  const LiquidPrismSegmentedControl({
    super.key,
    required this.children,
    required this.selectedValue,
    required this.onValueChanged,
    this.label,
    this.backgroundColor,
    this.thumbColor,
    this.foregroundColor,
    this.style,
    this.motion,
    this.onChangeStart,
    this.onChangeEnd,
  });
  final Map<T, Widget> children;
  final T selectedValue;
  final ValueChanged<T>? onValueChanged;
  final String? label;
  final Color? backgroundColor, thumbColor, foregroundColor;
  final GlassSegmentedStyle? style;
  final GlassControlMotion? motion;
  final ValueChanged<T>? onChangeStart, onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = LiquidPrismTheme.of(context);
    final appearance = (theme.segmentedControl ?? const GlassSegmentedStyle())
        .merge(style);
    final timing = (theme.controlMotion ?? const GlassControlMotion()).merge(
      motion,
    );
    final scale = appearance.scale ?? 1;
    final hitHeight = math.max(44.0, (appearance.hitHeight ?? 44) * scale);
    final trackHeight = (appearance.trackHeight ?? 32) * scale;
    final thumbHeight = (appearance.thumbHeight ?? 28) * scale;
    final inset = (appearance.selectionInset ?? 2) * scale;
    final liftInset = (appearance.liftInset ?? const Size(12, 8)) * scale;
    assert(liftInset.width >= 0 && liftInset.height >= 0);
    final colors = GlassColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    assert(children.length > 1 && children.length < 100);
    assert(children.containsKey(selectedValue));
    final keys = children.keys.toList();
    final count = keys.length, selected = keys.indexOf(selectedValue);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.constrainWidth(
          (appearance.width ?? 300) * scale,
        );
        if (width <= 0) return const SizedBox.shrink();
        final slot = width / count;
        return SizedBox(
          width: width,
          height: hitHeight,
          child: ControlInteraction(
            // Replacing/reordering keys cancels an obsolete in-flight gesture.
            key: ValueKey(Object.hashAll(keys)),
            value: selected / (count - 1),
            steps: count - 1,
            travel: slot * (count - 1),
            label: label,
            motion: timing,
            onChanged: onValueChanged == null
                ? null
                : (v) => onValueChanged!(keys[(v * (count - 1)).round()]),
            onChangeStart: onChangeStart == null
                ? null
                : (v) => onChangeStart!(
                    keys[(v * (count - 1)).round().clamp(0, count - 1)],
                  ),
            onChangeEnd: onChangeEnd == null
                ? null
                : (v) => onChangeEnd!(
                    keys[(v * (count - 1)).round().clamp(0, count - 1)],
                  ),
            positionAt: (x) =>
                ((((rtl ? width - x : x) / slot) - .5) / (count - 1)).clamp(
                  0.0,
                  1.0,
                ),
            spring: timing.travel?.description ?? NativeControl.segmentTravel,
            trackingSpring:
                timing.tracking?.description ?? NativeControl.segmentTracking,
            liftSpring: timing.lift?.description ?? NativeControl.largeLift,
            releaseSpring:
                timing.release?.description ?? NativeControl.largeLift,
            hangTime:
                timing.minimumLiftDuration ?? const Duration(milliseconds: 220),
            builder: (context, position, lift, stretch, activate) {
              final preview = (position * (count - 1)).round().clamp(
                0,
                count - 1,
              );
              final visualSelection = lift > .001 ? preview : selected;
              final physical = (rtl ? 1 - position : position) * (count - 1);
              final pillWidth =
                      math.max(.001, slot - 2 * inset) +
                      2 * liftInset.width * lift,
                  pillHeight = thumbHeight + 2 * liftInset.height * lift;
              return ControlDisabled(
                enabled: onValueChanged != null,
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
                            backgroundColor ??
                            appearance.backgroundColor ??
                            colors.tertiarySystemFill,
                      ),
                    ),
                    Positioned(
                      left: slot * (physical + .5) - pillWidth / 2,
                      top: hitHeight / 2 - pillHeight / 2,
                      width: pillWidth,
                      height: pillHeight,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(
                          1 + stretch,
                          1 - stretch,
                          1,
                        ),
                        child: ControlThumb(
                          lift: lift,
                          small: false,
                          color: thumbColor ?? appearance.thumbColor,
                          style: appearance.lens,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        children: [
                          for (var i = 0; i < count; i++)
                            Expanded(
                              child: Semantics(
                                button: true,
                                selected: i == selected,
                                inMutuallyExclusiveGroup: true,
                                enabled: onValueChanged != null,
                                onTap: onValueChanged == null
                                    ? null
                                    : () => activate(i / (count - 1)),
                                child: Center(
                                  child: DefaultTextStyle.merge(
                                    style:
                                        TextStyle(
                                              fontSize: 13 * scale,
                                              fontWeight: i == visualSelection
                                                  ? FontWeight.w500
                                                  : FontWeight.w400,
                                            )
                                            .merge(appearance.labelStyle)
                                            .copyWith(
                                              color:
                                                  foregroundColor ??
                                                  appearance.foregroundColor ??
                                                  (i == selected && lift < .5
                                                      ? appearance
                                                            .selectedForegroundColor
                                                      : null) ??
                                                  appearance
                                                      .labelStyle
                                                      ?.color ??
                                                  (i == selected && lift < .5
                                                      ? colors.controlThumbLabel
                                                      : colors.label),
                                            ),
                                    child: children[keys[i]]!,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
