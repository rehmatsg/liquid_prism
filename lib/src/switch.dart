import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'control_interaction.dart';
import 'control_material.dart';
import 'theme.dart';
import 'haptics.dart';
import 'appearance.dart';
import 'motion.dart';
import 'material.dart';

/// A controlled iOS-style switch with a capsule thumb and a lifted glass lens.
/// The parent owns [value]. A null [onChanged] disables every input path.
class LiquidPrismSwitch extends StatelessWidget {
  const LiquidPrismSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    bool? haptics,
    this.style,
    this.motion,
    this.onChangeStart,
    this.onChangeEnd,
  }) : haptics = haptics ?? true,
       _hasHaptics = haptics != null;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final Color? activeColor, inactiveColor, thumbColor;

  /// Native light impact on iOS when a tap or drag changes the toggle state.
  final bool haptics;
  final bool _hasHaptics;
  final GlassSwitchStyle? style;
  final GlassControlMotion? motion;
  final ValueChanged<bool>? onChangeStart, onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = LiquidPrismTheme.of(context);
    final appearance = (theme.switchStyle ?? const GlassSwitchStyle()).merge(
      style,
    );
    final timing = (theme.controlMotion ?? const GlassControlMotion()).merge(
      motion,
    );
    final scale = appearance.scale ?? 1;
    final width = (appearance.width ?? 63) * scale;
    final trackHeight = (appearance.trackHeight ?? 28) * scale;
    final hitWidth = math.max(44.0, width);
    final hitHeight = math.max(44.0, (appearance.hitHeight ?? 44) * scale);
    final inset = (appearance.inset ?? 2) * scale;
    final thumb = (appearance.thumbSize ?? const Size(37, 24)) * scale;
    final held =
        (appearance.liftedThumbSize ?? const Size(58, 115 / 3)) * scale;
    assert(
      thumb.width > 0 && thumb.height > 0 && held.width > 0 && held.height > 0,
    );
    assert(
      width > thumb.width + 2 * inset,
      'Switch width must leave room for thumb travel.',
    );
    final travel = width - thumb.width - 2 * inset;
    final start = inset + thumb.width / 2;
    final offset = (hitWidth - width) / 2;
    final feedback = _hasHaptics ? haptics : appearance.haptics ?? true;
    final colors = GlassColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // UISwitch's visible well is 63x28; its hit area is extended to 44 points.
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
            ? () => dispatchGlassHaptic(
                context,
                const GlassHapticEvent(
                  GlassHapticComponent.switchControl,
                  GlassHapticKind.toggle,
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
                    shape: appearance.trackShape ?? GlassShape.capsule,
                    color: Color.lerp(
                      inactiveColor ??
                          appearance.inactiveColor ??
                          colors.tertiaryLabel,
                      activeColor ??
                          appearance.activeColor ??
                          LiquidPrismTheme.of(context).tint ??
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
  }
}
