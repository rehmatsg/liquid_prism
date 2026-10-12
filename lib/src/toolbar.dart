import 'dart:async';

import 'package:flutter/widgets.dart';

import 'chrome_material.dart';
import 'foreground.dart';
import 'material.dart';
import 'motion.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'style.dart';
import 'theme.dart';

/// Native navigation bars use 44-point capsules; bottom toolbars use 48.
enum GlassToolbarSize { navigation, bottom }

/// One icon action in a shared toolbar capsule.
@immutable
class GlassToolbarItem {
  const GlassToolbarItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.key,
    this.selected = false,
    this.foregroundColor,
    this.width = 38,
  }) : assert(width >= 36);
  final Widget icon;
  final String label;
  final FutureOr<void> Function()? onPressed;
  final Key? key;
  final bool selected;
  final Color? foregroundColor;

  /// Native item width depends on the symbol. The captured minimum is 38;
  /// callers can supply the measured width for wider or custom symbols.
  final double width;
}

/// Icon actions sharing one continuous glass capsule, with individual feedback.
/// Place separate groups in a Row with a gap or Spacer. Narrow groups scroll
/// horizontally without shrinking their icons or action regions.
class LiquidPrismToolbarGroup extends StatelessWidget {
  const LiquidPrismToolbarGroup({
    super.key,
    required this.items,
    this.size = GlassToolbarSize.bottom,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.foregroundColor,
  }) : assert(items.length > 0);
  final List<GlassToolbarItem> items;
  final GlassToolbarSize size;
  final Glass? glass;
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassMotion? motion;
  final Color? foregroundColor;
  @override
  Widget build(BuildContext context) {
    final navigation = size == GlassToolbarSize.navigation;
    final height = navigation ? 44.0 : 48.0;
    final inset = navigation ? 4.0 : 5.0;
    final gap = navigation ? 16.0 : 14.0;
    final theme = LiquidPrismTheme.of(context),
        colors = GlassColors.of(context);
    final foreground =
        foregroundColor ??
        theme.foregroundColor ??
        restingGlassAccent(LiquidPrismTheme.tintOf(context), colors.brightness);
    final width =
        items.fold<double>(0, (sum, item) => sum + item.width) +
        gap * (items.length - 1) +
        inset * 2;
    final capsule = SizedBox(
      width: width,
      height: height,
      child: ChromeMaterial(
        height: height,
        role: GlassRole.toolbar,
        glass: glass,
        optics: optics,
        blur: blur,
        child: ClipPath(
          clipper: const GlassShapeClipper(GlassShape.capsule),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  _action(items[i], i, height, inset, gap, colors, foreground),
              ],
            ),
          ),
        ),
      ),
    );
    if (items.every((item) => item.onPressed == null)) return capsule;
    final customMotion = motion ?? theme.motion;
    return LiquidPrismPressable.feedback(
      motion: customMotion,
      child: Builder(
        builder: (context) {
          final scale = LiquidPrismPressFeedback.scaleOf(context);
          // Captured widths 159, 100 and 48 all gain 16 points while held.
          // Normalize the shared feedback spring without bounding small circles
          // to the ordinary button motion API's maximum scale.
          return LiquidPrismPressFeedback(
            progress: LiquidPrismPressFeedback.of(context),
            scale: customMotion == null
                ? 1 + (scale - 1) * (16 / width / .1126)
                : scale,
            child: capsule,
          );
        },
      ),
    );
  }

  Widget _action(
    GlassToolbarItem item,
    int index,
    double height,
    double inset,
    double gap,
    GlassColors colors,
    Color foreground,
  ) {
    final left = index == 0 ? inset : gap / 2;
    final right = index == items.length - 1 ? inset : gap / 2;
    return LiquidPrismPressable.glass(
      key: item.key,
      label: item.label,
      selected: item.selected,
      motion: motion,
      onPressed: item.onPressed,
      child: Builder(
        builder: (context) {
          final press = LiquidPrismPressFeedback.of(context);
          final color = item.onPressed == null
              ? colors.disabledLabel
              : item.foregroundColor ?? foreground;
          return SizedBox(
            width: item.width + left + right,
            height: height,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: left, end: right),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: inset),
                    child: ClipPath(
                      clipper: const GlassShapeClipper(GlassShape.capsule),
                      child: ColoredBox(
                        color: colors.label.withValues(alpha: .12 * press),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  IconTheme.merge(
                    // Native symbol image views enlarge their source images.
                    // 22-point Cupertino glyphs leave too much visible space
                    // between actions despite matching native item centers.
                    data: IconThemeData(color: color, size: 25.5),
                    child: item.icon,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
