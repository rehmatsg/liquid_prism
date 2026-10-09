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
import 'system_glass.dart';
import 'motion.dart';
import 'vibrancy.dart';

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
    this.rendering,
    this.motion,
    this.buttonStyle = GlassButtonStyle.glass,
    this.shape,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    this.selected = false,
    this.foregroundColor,
  });
  final FutureOr<void> Function()? onPressed;
  final Widget child;
  final String label;
  final Glass? glass;
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassRendering? rendering;
  final GlassMotion? motion;
  final GlassButtonStyle buttonStyle;
  final GlassShape? shape;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final Color? foregroundColor;
  @override
  Widget build(BuildContext context) {
    final colors = LiquidPrismTheme.colorsOf(context);
    final tint = LiquidPrismTheme.tintOf(context);
    final prominent = buttonStyle == GlassButtonStyle.glassProminent;
    final enabled = onPressed != null;
    final explicitForeground =
        foregroundColor ??
        (prominent ? null : LiquidPrismTheme.of(context).foregroundColor);
    final base = glass ?? LiquidPrismTheme.of(context).glass ?? Glass.regular;
    final material = prominent && base.tintColor == null
        ? base.tint(tint)
        : base;
    return LiquidPrismPressable.glass(
      label: label,
      motion: motion,
      selected: selected,
      onPressed: onPressed,
      child: LiquidPrism(
        glass: material.interactive(false),
        shape: shape,
        optics: optics,
        blur: blur,
        rendering: rendering,
        role: GlassRole.button,
        child: Builder(
          builder: (context) {
            final resting = usesRestingGlassPalette(context);
            final foreground = !enabled
                ? colors.disabledLabel
                : explicitForeground ??
                      (prominent
                          ? const Color(0xFFFFFFFF)
                          : resting
                          ? restingGlassAccent(tint, colors.brightness)
                          : tint);
            return Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: foreground,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(color: foreground),
                  child: GlassVibrantForeground(
                    enabled:
                        enabled &&
                        !resting &&
                        !prominent &&
                        explicitForeground == null,
                    tint: tint,
                    brightness: colors.brightness,
                    child: child,
                  ),
                ),
              ),
            );
          },
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
