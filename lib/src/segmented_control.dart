import 'package:flutter/widgets.dart';

import 'control_interaction.dart';
import 'control_material.dart';
import 'theme.dart';

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
  });
  final Map<T, Widget> children;
  final T selectedValue;
  final ValueChanged<T>? onValueChanged;
  final String? label;
  final Color? backgroundColor, thumbColor, foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = GlassColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    assert(children.length > 1 && children.length < 100);
    assert(children.containsKey(selectedValue));
    final keys = children.keys.toList();
    final count = keys.length, selected = keys.indexOf(selectedValue);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.constrainWidth(300);
        final slot = width / count;
        return SizedBox(
          width: width,
          height: 44,
          child: ControlInteraction(
            // Replacing/reordering keys cancels an obsolete in-flight gesture.
            key: ValueKey(Object.hashAll(keys)),
            value: selected / (count - 1),
            steps: count - 1,
            travel: slot * (count - 1),
            label: label,
            onChanged: onValueChanged == null
                ? null
                : (v) => onValueChanged!(keys[(v * (count - 1)).round()]),
            positionAt: (x) =>
                ((((rtl ? width - x : x) / slot) - .5) / (count - 1)).clamp(
                  0.0,
                  1.0,
                ),
            spring: NativeControl.segmentTravel,
            trackingSpring: NativeControl.segmentTracking,
            liftSpring: NativeControl.largeLift,
            releaseSpring: NativeControl.largeLift,
            hangTime: const Duration(milliseconds: 220),
            builder: (context, position, lift, stretch, activate) {
              final preview = (position * (count - 1)).round().clamp(
                0,
                count - 1,
              );
              final visualSelection = lift > .001 ? preview : selected;
              final physical = (rtl ? 1 - position : position) * (count - 1);
              final pillWidth = slot - 4 + 24 * lift,
                  pillHeight = 28 + 16 * lift;
              return ControlDisabled(
                enabled: onValueChanged != null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: 6,
                      width: width,
                      height: 32,
                      child: ControlTrack(
                        color: backgroundColor ?? colors.tertiarySystemFill,
                      ),
                    ),
                    Positioned(
                      left: slot * (physical + .5) - pillWidth / 2,
                      top: 22 - pillHeight / 2,
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
                          color: thumbColor,
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
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: i == visualSelection
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                      color:
                                          foregroundColor ??
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
