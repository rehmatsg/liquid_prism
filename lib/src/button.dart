import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'foreground.dart';
import 'material.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'theme.dart';
import 'style.dart';
import 'motion.dart';
import 'menu/menu.dart';
import 'menu/menus.dart';

enum GlassButtonStyle { glass, glassProminent }

/// Glass material, sharp content and one interruptible interaction owner.
///
/// Null [onPressed] disables touch, keyboard and accessibility activation. Async
/// callbacks may overlap; disable the button explicitly for exclusive work.
class LiquidPrismButton extends StatelessWidget {
  const LiquidPrismButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.label,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.buttonStyle = GlassButtonStyle.glass,
    this.shape,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    this.selected = false,
    this.foregroundColor,
  }) : menu = null,
       onMenuSelected = null,
       _menuEnabled = false;

  /// A glass trigger for the native UIKit menu supplied by Liquid Menu.
  /// The existing button owns touch, keyboard and accessibility activation.
  const LiquidPrismButton.menu({
    super.key,
    required LiquidMenu this.menu,
    required this.child,
    required this.label,
    ValueChanged<Object?>? onSelected,
    bool enabled = true,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.buttonStyle = GlassButtonStyle.glass,
    this.shape,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    this.selected = false,
    this.foregroundColor,
  }) : onPressed = null,
       onMenuSelected = onSelected,
       _menuEnabled = enabled;
  final FutureOr<void> Function()? onPressed;
  final Widget child;
  final String label;
  final Glass? glass;
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassMotion? motion;
  final GlassButtonStyle buttonStyle;
  final GlassShape? shape;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final Color? foregroundColor;
  final LiquidMenu? menu;
  final ValueChanged<Object?>? onMenuSelected;
  final bool _menuEnabled;
  @override
  Widget build(BuildContext context) {
    final theme = LiquidPrismTheme.of(context);
    final colors = LiquidPrismTheme.colorsOf(context);
    final tint = LiquidPrismTheme.tintOf(context);
    final prominent = buttonStyle == GlassButtonStyle.glassProminent;
    final enabled = menu == null ? onPressed != null : _menuEnabled;
    final action = menu == null
        ? onPressed
        : !enabled
        ? null
        : () async {
            final result = await liquidMenus.show<Object?>(
              context: context,
              menu: menu!,
            );
            if (context.mounted) onMenuSelected?.call(result);
          };
    final explicitForeground =
        foregroundColor ?? (prominent ? null : theme.foregroundColor);
    final base = glass ?? theme.glass ?? Glass.regular;
    final material = prominent && base.tintColor == null
        ? base.tint(tint)
        : base;
    final foreground = !enabled
        ? colors.disabledLabel
        : explicitForeground ??
              (prominent
                  ? const Color(0xFFFFFFFF)
                  : restingGlassAccent(tint, colors.brightness));
    return LiquidPrismPressable.glass(
      label: label,
      motion: motion,
      selected: selected,
      onPressed: action,
      child: LiquidPrism(
        glass: material.interactive(false),
        shape: shape,
        optics: optics,
        blur: blur,
        role: GlassRole.button,
        child: Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: foreground,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: foreground),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(EnumProperty('buttonStyle', buttonStyle))
      ..add(DiagnosticsProperty<Glass>('glass', glass))
      ..add(DiagnosticsProperty<LiquidPrismStyle>('optics', optics))
      ..add(DoubleProperty('blur', blur))
      ..add(DiagnosticsProperty<GlassShape>('shape', shape))
      ..add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding))
      ..add(ColorProperty('foregroundColor', foregroundColor))
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'))
      ..add(
        ObjectFlagProperty<FutureOr<void> Function()>.has(
          'onPressed',
          onPressed,
        ),
      );
  }
}
