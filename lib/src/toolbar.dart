import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'chrome_layout.dart';
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
    double? width,
  }) : menu = null,
       onMenuSelected = null,
       _menuEnabled = false,
       width = width ?? 38,
       _hasWidth = width != null,
       assert(width == null || width >= 36);

  const GlassToolbarItem.menu({
    required this.icon,
    required this.label,
    required LiquidMenu this.menu,
    ValueChanged<Object?>? onSelected,
    bool enabled = true,
    this.key,
    this.selected = false,
    this.foregroundColor,
    double? width,
  }) : onPressed = null,
       onMenuSelected = onSelected,
       _menuEnabled = enabled,
       width = width ?? 38,
       _hasWidth = width != null,
       assert(width == null || width >= 36);
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
  ///
  /// Left unset on the only item of a group, the item fills a circle: the
  /// group is as wide as it is tall (44 points in a navigation bar, 48 in a
  /// bottom toolbar), as native iOS draws a lone bar button. An explicit width
  /// is kept, so a wider custom item stays a capsule.
  final double width;
  final bool _hasWidth;
}

/// Icon actions sharing one continuous glass capsule, with individual feedback.
/// Place separate groups in a Row with a gap or Spacer. Narrow groups scroll
/// along their axis without shrinking their icons or action regions.
///
/// A vertical group stacks the same layout in a column, as in the iPhone Duo
/// side rail: [GlassToolbarItem.width] becomes each item's height.
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
    this.axis,
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

  /// Row or column layout. Null inherits [LiquidPrismScaffold]'s bar axis,
  /// then defaults to [Axis.horizontal].
  final Axis? axis;
  @override
  Widget build(BuildContext context) {
    final vertical =
        (axis ?? LiquidPrismChrome.maybeOf(context)?.axis) == Axis.vertical;
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
    final widths = _itemWidths(height, inset);
    final width =
        widths.fold<double>(0, (sum, extent) => sum + extent) +
        gap * (items.length - 1) +
        inset * 2;
    final capsule = SizedBox(
      width: vertical ? height : width,
      height: vertical ? width : height,
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
            scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
            child: Flex(
              direction: vertical ? Axis.vertical : Axis.horizontal,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++)
                  _action(
                    items[i],
                    widths[i],
                    i,
                    height,
                    inset,
                    gap,
                    colors,
                    foreground,
                    appearance,
                    vertical,
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

  /// Visual item extents along the group's axis. A lone item without an
  /// explicit width fills a circle, as UIKit measured: a 36-point button in the
  /// 44-point navigation circle and a 38-point button in the 48-point bottom one.
  List<double> _itemWidths(double height, double inset) => [
    if (items.length == 1 && !items.single._hasWidth)
      math.max(height - inset * 2, 0)
    else
      for (final item in items) item.width,
  ];

  Widget _action(
    GlassToolbarItem item,
    double itemWidth,
    int index,
    double height,
    double inset,
    double gap,
    GlassColors colors,
    Color foreground,
    GlassToolbarStyle appearance,
    bool vertical,
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
            final extent = itemWidth + left + right;
            return SizedBox(
              width: vertical ? height : extent,
              height: vertical ? extent : height,
              child: Padding(
                padding: vertical
                    ? EdgeInsets.only(top: left, bottom: right)
                    : EdgeInsetsDirectional.only(start: left, end: right),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: vertical
                          ? EdgeInsets.symmetric(horizontal: inset)
                          : EdgeInsets.symmetric(vertical: inset),
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
