import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/controls/control_interaction.dart';
import 'package:liquid_prism/src/controls/control_material.dart';
import 'package:liquid_prism/src/controls/prism_switch_style.dart';
import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_haptics.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// A parent-controlled switch with a lifted glass thumb.
class PrismSwitch extends StatelessWidget {
  /// Creates a controlled switch.
  const new({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.onChangeStart,
    this.onChangeEnd,
    this.style,
  });

  /// Parent-owned toggle value.
  final bool value;

  /// Proposes a toggle value; null disables all input.
  final ValueChanged<bool>? onChanged;

  /// Accessible name for the switch.
  final String? label;

  /// Visual and motion overrides merged over the component theme.
  final PrismSwitchStyle? style;

  /// Called when user input starts.
  final ValueChanged<bool>? onChangeStart;

  /// Called when user input ends.
  final ValueChanged<bool>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = PrismTheme.of(context);
    final appearance = (theme.switchStyle ?? const PrismSwitchStyle()).merge(
      style,
    );
    final timing = (theme.controlMotion ?? const PrismControlMotion()).merge(
      appearance.motion,
    );
    final scale = appearance.scale ?? 1;
    final width = (appearance.width ?? 63) * scale;
    final trackHeight = (appearance.trackHeight ?? 28) * scale;
    final hitWidth = math.max<double>(44, width);
    final hitHeight = math.max<double>(
      44,
      (appearance.hitHeight ?? 44) * scale,
    );
    final inset = (appearance.inset ?? 2) * scale;
    final thumb = (appearance.thumbSize ?? const Size(37, 24)) * scale;
    final held =
        (appearance.liftedThumbSize ?? const Size(58, 115 / 3)) * scale;
    assert(
      thumb.width > 0 && thumb.height > 0 && held.width > 0 && held.height > 0,
      'Resting and lifted thumb dimensions must be positive.',
    );
    assert(
      width > thumb.width + 2 * inset,
      'Switch width must leave room for thumb travel.',
    );
    final travel = width - thumb.width - 2 * inset;
    final start = inset + thumb.width / 2;
    final offset = (hitWidth - width) / 2;
    final feedback = appearance.haptics ?? true;
    final colors = PrismTheme.colorsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      width: hitWidth,
      height: hitHeight,
      child: ControlInteraction(
        value: value ? 1 : 0,
        toggle: true,
        steps: 1,
        onChanged: onChanged == null ? null : (v) => onChanged!(v >= .5),
        onChangeStart: onChangeStart == null
            ? null
            : (v) => onChangeStart!(v >= .5),
        onChangeEnd: onChangeEnd == null ? null : (v) => onChangeEnd!(v >= .5),
        onSelectionFeedback:
            feedback &&
                (theme.haptics != null ||
                    defaultTargetPlatform == TargetPlatform.iOS)
            ? () => dispatchPrismHaptic(
                context,
                const PrismHapticEvent(
                  PrismHapticComponent.switchControl,
                  PrismHapticKind.toggle,
                ),
              )
            : null,
        label: label,
        travel: travel,
        positionAt: (x) =>
            ((rtl ? width - (x - offset) : x - offset) - start) / travel,
        motion: timing,

        spring: timing.travel?.description ?? NativeControl.switchTravel,
        trackingSpring:
            timing.tracking?.description ?? NativeControl.switchTravel,
        liftSpring: timing.lift?.description ?? NativeControl.smallLift,
        releaseSpring:
            timing.release?.description ?? NativeControl.smallRelease,
        hangTime: timing.minimumLiftDuration ?? NativeControl.switchHangTime,
        builder: (context, position, lift, stretch, activate) {
          final p = position.clamp(0.0, 1.0);
          final physical = rtl ? 1 - p : p;
          final thumbWidth = thumb.width + (held.width - thumb.width) * lift;
          final thumbHeight =
              thumb.height + (held.height - thumb.height) * lift;
          return ControlDisabled(
            enabled: onChanged != null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: (hitHeight - trackHeight) / 2,
                  left: offset,
                  width: width,
                  height: trackHeight,
                  child: ControlTrack(
                    shape: appearance.trackShape ?? PrismShape.capsule,
                    color: Color.lerp(
                      appearance.inactiveColor ?? colors.tertiaryLabel,
                      appearance.activeColor ??
                          PrismTheme.of(context).tint ??
                          colors.green,
                      p,
                    )!,
                  ),
                ),
                Positioned(
                  left: offset + start + travel * physical - thumbWidth / 2,
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
  }
}
