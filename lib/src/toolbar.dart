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
import 'appearance.dart';
import 'menu/menu.dart';
import 'menu/menus.dart';

/// Native navigation bars use 44-point capsules; bottom toolbars use 48.
export 'appearance.dart' show GlassToolbarSize;

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
  }) : menu = null,
       onMenuSelected = null,
       _menuEnabled = false,
       assert(width >= 36);

  const GlassToolbarItem.menu({
    required this.icon,
    required this.label,
    required LiquidMenu this.menu,
    ValueChanged<Object?>? onSelected,
    bool enabled = true,
    this.key,
    this.selected = false,
    this.foregroundColor,
    this.width = 38,
  }) : onPressed = null,
       onMenuSelected = onSelected,
       _menuEnabled = enabled,
       assert(width >= 36);
  final Widget icon;
  final String label;
  final FutureOr<void> Function()? onPressed;
  final Key? key;
  final bool selected;
  final Color? foregroundColor;
  final LiquidMenu? menu;
  final ValueChanged<Object?>? onMenuSelected;
  final bool _menuEnabled;
  bool get _isEnabled => menu == null ? onPressed != null : _menuEnabled;

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
    GlassToolbarSize? size,
    this.style,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.foregroundColor,
  }) : size = size ?? GlassToolbarSize.bottom,
       _hasSize = size != null,
       assert(items.length > 0);
  final List<GlassToolbarItem> items;
  final GlassToolbarSize size;
  final bool _hasSize;
  final GlassToolbarStyle? style;
  final Glass? glass;
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassMotion? motion;
  final Color? foregroundColor;
  @override
  Widget build(BuildContext context) {
    final theme = LiquidPrismTheme.of(context),
        colors = GlassColors.of(context);
    final appearance = (theme.toolbar ?? const GlassToolbarStyle()).merge(
      style,
    );
    final placement = _hasSize ? size : appearance.size ?? size;
    final navigation = placement == GlassToolbarSize.navigation;
    final height = appearance.height ?? (navigation ? 44.0 : 48.0);
    final inset = appearance.inset ?? (navigation ? 4.0 : 5.0);
    final gap = appearance.spacing ?? (navigation ? 16.0 : 14.0);
    final foreground =
        foregroundColor ??
        appearance.foregroundColor ??
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
        glass: glass ?? appearance.glass,
        optics: optics ?? appearance.optics,
        blur: blur ?? appearance.blur,
        shape: appearance.shape,
        child: ClipPath(
          clipper: GlassShapeClipper(appearance.shape ?? GlassShape.capsule),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  _action(
                    items[i],
                    i,
                    height,
                    inset,
                    gap,
                    colors,
                    foreground,
                    appearance,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (items.every((item) => !item._isEnabled)) return capsule;
    final customMotion = motion ?? appearance.motion ?? theme.motion;
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
    GlassToolbarStyle appearance,
  ) {
    final left = index == 0 ? inset : gap / 2;
    final right = index == items.length - 1 ? inset : gap / 2;
    return Builder(
      builder: (actionContext) => LiquidPrismPressable.glass(
        key: item.key,
        label: item.label,
        selected: item.selected,
        motion: motion ?? appearance.motion,
        onPressed: item.menu == null
            ? item.onPressed
            : !item._isEnabled
            ? null
            : () async {
                final result = await liquidMenus.show<Object?>(
                  context: actionContext,
                  menu: item.menu!,
                );
                if (actionContext.mounted) item.onMenuSelected?.call(result);
              },
        child: Builder(
          builder: (context) {
            final press = LiquidPrismPressFeedback.of(context);
            final color = !item._isEnabled
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
                        clipper: GlassShapeClipper(
                          appearance.itemShape ?? GlassShape.capsule,
                        ),
                        child: ColoredBox(
                          color:
                              (appearance.pressedColor ??
                                      colors.label.withValues(alpha: .12))
                                  .withValues(
                                    alpha:
                                        (appearance.pressedColor?.a ?? .12) *
                                        press,
                                  ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    IconTheme.merge(
                      // Native symbol image views enlarge their source images.
                      // 22-point Cupertino glyphs leave too much visible space
                      // between actions despite matching native item centers.
                      data: IconThemeData(
                        color: color,
                        size: appearance.iconSize ?? 25.5,
                      ),
                      child: item.icon,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
