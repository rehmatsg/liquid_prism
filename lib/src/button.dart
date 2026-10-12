import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'foreground.dart';
import 'material.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'theme.dart';
import 'appearance.dart';
import 'style.dart';
import 'motion.dart';
import 'menu/menu.dart';
import 'menu/menus.dart';

export 'appearance.dart' show GlassButtonStyle;

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
    GlassButtonStyle? buttonStyle,
    this.style,
    this.shape,
    EdgeInsetsGeometry? padding,
    this.selected = false,
    this.foregroundColor,
  }) : buttonStyle = buttonStyle ?? GlassButtonStyle.glass,
       _hasButtonStyle = buttonStyle != null,
       padding =
           padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
       _hasPadding = padding != null,
       _iconOnly = false,
       menu = null,
       onMenuSelected = null,
       _menuEnabled = false;

  /// A circular icon action with a 48-point minimum extent.
  const LiquidPrismButton.icon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required this.label,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    GlassButtonStyle? buttonStyle,
    this.style,
    this.shape,
    EdgeInsetsGeometry? padding,
    this.selected = false,
    this.foregroundColor,
  }) : child = icon,
       buttonStyle = buttonStyle ?? GlassButtonStyle.glass,
       _hasButtonStyle = buttonStyle != null,
       padding = padding ?? const EdgeInsets.all(12),
       _hasPadding = padding != null,
       _iconOnly = true,
       menu = null,
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
    GlassButtonStyle? buttonStyle,
    this.style,
    this.shape,
    EdgeInsetsGeometry? padding,
    this.selected = false,
    this.foregroundColor,
  }) : buttonStyle = buttonStyle ?? GlassButtonStyle.glass,
       _hasButtonStyle = buttonStyle != null,
       padding =
           padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
       _hasPadding = padding != null,
       _iconOnly = false,
       onPressed = null,
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
  final GlassButtonAppearance? style;
  final bool _hasButtonStyle, _hasPadding, _iconOnly;
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
    final appearance = (theme.button ?? const GlassButtonAppearance()).merge(
      style,
    );
    final colors = LiquidPrismTheme.colorsOf(context);
    final tint = LiquidPrismTheme.tintOf(context);
    final treatment = _hasButtonStyle
        ? buttonStyle
        : appearance.buttonStyle ?? buttonStyle;
    final prominent = treatment == GlassButtonStyle.glassProminent;
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
        foregroundColor ??
        appearance.foregroundColor ??
        appearance.textStyle?.color ??
        (prominent ? null : theme.foregroundColor);
    final base = glass ?? appearance.glass ?? theme.glass ?? Glass.regular;
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
      motion: motion ?? appearance.motion,
      selected: selected,
      onPressed: action,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: appearance.minimumSize?.width ?? (_iconOnly ? 48 : 0),
          minHeight: appearance.minimumSize?.height ?? (_iconOnly ? 48 : 0),
        ),
        child: LiquidPrism(
          glass: material.interactive(false),
          shape:
              shape ??
              appearance.shape ??
              (_iconOnly ? GlassShape.circle : null),
          optics: optics ?? appearance.optics,
          blur: blur ?? appearance.blur,
          role: GlassRole.button,
          child: Padding(
            padding: _hasPadding ? padding : appearance.padding ?? padding,
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ).merge(appearance.textStyle).copyWith(color: foreground),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: foreground,
                  size: appearance.iconSize,
                ),
                child: child,
              ),
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
