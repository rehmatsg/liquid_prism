import 'package:flutter/widgets.dart';

import 'control_interaction.dart';
import 'control_material.dart';
import 'theme.dart';

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
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final Color? activeColor, inactiveColor, thumbColor;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // UISwitch's visible well is 63x28; its hit area is extended to 44 points.
    return SizedBox(
      width: 63,
      height: 44,
      child: ControlInteraction(
        value: value ? 1 : 0,
        toggle: true,
        steps: 1,
        onChanged: onChanged == null ? null : (v) => onChanged!(v >= .5),
        label: label,
        travel: 22,
        positionAt: (x) => ((rtl ? 63 - x : x) - 20.5) / 22,
        spring: NativeControl.switchTravel,
        trackingSpring: NativeControl.switchTravel,
        liftSpring: NativeControl.smallLift,
        releaseSpring: NativeControl.smallRelease,
        builder: (context, position, lift, stretch, activate) {
          final p = position.clamp(0.0, 1.0);
          final physical = rtl ? 1 - p : p;
          final width = 37 + 21 * lift, height = 24 + (43 / 3) * lift;
          return ControlDisabled(
            enabled: onChanged != null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 8,
                  left: 0,
                  width: 63,
                  height: 28,
                  child: ControlTrack(
                    color: Color.lerp(
                      inactiveColor ?? colors.tertiaryLabel,
                      activeColor ??
                          LiquidPrismTheme.of(context).tint ??
                          colors.green,
                      p,
                    )!,
                  ),
                ),
                Positioned(
                  left: 20.5 + 22 * physical - width / 2,
                  top: 22 - height / 2,
                  width: width,
                  height: height,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(
                      1 + stretch,
                      1 - stretch,
                      1,
                    ),
                    child: ControlThumb(lift: lift, color: thumbColor),
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
