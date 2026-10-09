import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'material.dart';
import 'style.dart';
import 'system_glass.dart';
import 'motion.dart';
import 'tab_bar_style.dart';

/// Default sRGB semantic colors for normal-contrast glass content.
/// These are source colors: native vibrancy can alter their displayed pixels.
@immutable
final class GlassColors {
  const GlassColors(this.brightness);
  final Brightness brightness;
  bool get _dark => brightness == Brightness.dark;

  Color get blue => Color(_dark ? 0xFF0091FF : 0xFF0088FF);
  Color get green => Color(_dark ? 0xFF30D158 : 0xFF34C759);
  Color get orange => Color(_dark ? 0xFFFF9230 : 0xFFFF8D28);
  Color get pink => Color(_dark ? 0xFFFF375F : 0xFFFF2D55);
  Color get label => Color(_dark ? 0xFFFFFFFF : 0xFF000000);
  Color get secondaryLabel => Color(_dark ? 0x99EBEBF5 : 0x993C3C43);
  Color get disabledLabel => Color(_dark ? 0x4CEBEBF5 : 0x4C3C3C43);
  Color get systemFill => Color(_dark ? 0x5C787880 : 0x33787880);
}

/// App-wide defaults. Widget arguments override these; nested themes merge.
@immutable
class LiquidPrismThemeData {
  const LiquidPrismThemeData({
    this.brightness,
    this.tint,
    this.foregroundColor,
    this.glass,
    this.optics,
    this.blur,
    this.shape,
    this.motion,
    this.tabBar,
    this.rendering,
  }) : assert(blur == null || (blur >= 0 && blur <= 12));
  final Brightness? brightness;
  final Color? tint;

  /// Literal accent foreground for ordinary buttons and selected tabs.
  /// Null uses the calibrated appearance; prominent buttons retain white.
  final Color? foregroundColor;
  final Glass? glass;
  final LiquidPrismStyle? optics;

  /// Gaussian blur in logical pixels. Null retains the material default.
  final double? blur;
  final GlassRendering? rendering;
  final GlassShape? shape;
  final GlassMotion? motion;
  final GlassTabBarStyle? tabBar;

  LiquidPrismThemeData merge(LiquidPrismThemeData other) =>
      LiquidPrismThemeData(
        brightness: other.brightness ?? brightness,
        tint: other.tint ?? tint,
        foregroundColor: other.foregroundColor ?? foregroundColor,
        glass: other.glass ?? glass,
        optics: other.optics ?? optics,
        blur: other.blur ?? blur,
        shape: other.shape ?? shape,
        rendering: other.rendering ?? rendering,
        motion: other.motion ?? motion,
        tabBar: (tabBar ?? const GlassTabBarStyle()).merge(other.tabBar),
      );
}

/// Place above the app's routes to share optics, motion and control defaults.
/// A nested theme inherits unspecified fields. Set [inherit] false to reset.
class LiquidPrismTheme extends StatelessWidget {
  const LiquidPrismTheme({
    super.key,
    this.brightness,
    this.tint,
    this.data = const LiquidPrismThemeData(),
    this.inherit = true,
    required this.child,
  });
  final Brightness? brightness;
  final Color? tint;
  final LiquidPrismThemeData data;
  final bool inherit;
  final Widget child;
  static LiquidPrismThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassThemeScope>()?.data ??
      const LiquidPrismThemeData();
  static Brightness brightnessOf(BuildContext context) =>
      of(context).brightness ?? MediaQuery.platformBrightnessOf(context);
  static GlassColors colorsOf(BuildContext context) =>
      GlassColors(brightnessOf(context));
  static Color tintOf(BuildContext context) =>
      of(context).tint ?? colorsOf(context).blue;
  @override
  Widget build(BuildContext context) => _GlassThemeScope(
    data: (inherit ? of(context) : const LiquidPrismThemeData())
        .merge(data)
        .merge(LiquidPrismThemeData(brightness: brightness, tint: tint)),
    child: child,
  );
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty('brightness', brightness))
      ..add(ColorProperty('tint', tint))
      ..add(DiagnosticsProperty<LiquidPrismThemeData>('data', data))
      ..add(FlagProperty('inherit', value: inherit, ifTrue: 'inherit'));
  }
}

class _GlassThemeScope extends InheritedWidget {
  const _GlassThemeScope({required this.data, required super.child});
  final LiquidPrismThemeData data;
  @override
  bool updateShouldNotify(_GlassThemeScope oldWidget) => data != oldWidget.data;
}
