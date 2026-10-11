import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'material.dart';
import 'style.dart';
import 'motion.dart';
import 'tab_bar_style.dart';

/// Native iOS 27 semantic source colors, resolved for the current appearance.
/// These are tint inputs, not the final composited glass pixel colors.
@immutable
final class GlassColors {
  const GlassColors(this.brightness);
  static const light = GlassColors(Brightness.light);
  static const dark = GlassColors(Brightness.dark);
  static GlassColors of(BuildContext context) =>
      LiquidPrismTheme.colorsOf(context);
  final Brightness brightness;
  bool get _dark => brightness == Brightness.dark;

  Color get blue => _dark ? const Color(0xFF0091FF) : const Color(0xFF0088FF);
  Color get brown => _dark ? const Color(0xFFB78A66) : const Color(0xFFAC7F5E);
  Color get cyan => _dark ? const Color(0xFF3CD3FE) : const Color(0xFF00C0E8);
  Color get green => _dark ? const Color(0xFF30D158) : const Color(0xFF34C759);
  Color get indigo => _dark ? const Color(0xFF6D7CFF) : const Color(0xFF6155F5);
  Color get mint => _dark ? const Color(0xFF00DAC3) : const Color(0xFF00C8B3);
  Color get orange => _dark ? const Color(0xFFFF9230) : const Color(0xFFFF8D28);
  Color get pink => _dark ? const Color(0xFFFF375F) : const Color(0xFFFF2D55);
  Color get purple => _dark ? const Color(0xFFDB34F2) : const Color(0xFFCB30E0);
  Color get red => _dark ? const Color(0xFFFF4245) : const Color(0xFFFF383C);
  Color get teal => _dark ? const Color(0xFF00D2E0) : const Color(0xFF00C3D0);
  Color get yellow => _dark ? const Color(0xFFFFD600) : const Color(0xFFFFCC00);
  Color get label => _dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  /// Native modal dimming source, separated from the glass face.
  Color get sheetBarrier =>
      const Color(0xFF000000).withValues(alpha: _dark ? .48 : .2);

  /// Native full-height sheet background.
  Color get sheetBackground =>
      _dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);

  /// Native small-control resting fill, independent of appearance.
  Color get controlThumb => const Color(0xFFFFFFFF);

  /// Content above the opaque white segmented selection.
  Color get controlThumbLabel => const Color(0xFF000000);

  /// Extracted UISlider maximum track: 10% white/black in dark/light mode.
  Color get sliderTrack => _dark
      ? const Color.from(alpha: .1, red: 1, green: 1, blue: 1)
      : const Color.from(alpha: .1, red: 0, green: 0, blue: 0);
  Color get secondaryLabel => _dark
      ? const Color.from(
          alpha: 0.6,
          red: 235 / 255,
          green: 235 / 255,
          blue: 245 / 255,
        )
      : const Color.from(
          alpha: 0.6,
          red: 60 / 255,
          green: 60 / 255,
          blue: 67 / 255,
        );
  Color get tertiaryLabel => _dark
      ? const Color.from(
          alpha: 0.2980392156862745,
          red: 235 / 255,
          green: 235 / 255,
          blue: 245 / 255,
        )
      : const Color.from(
          alpha: 0.2980392156862745,
          red: 60 / 255,
          green: 60 / 255,
          blue: 67 / 255,
        );
  Color get quaternaryLabel => _dark
      ? const Color.from(
          alpha: 0.1568627450980392,
          red: 235 / 255,
          green: 235 / 255,
          blue: 245 / 255,
        )
      : const Color.from(
          alpha: 0.17647058823529413,
          red: 60 / 255,
          green: 60 / 255,
          blue: 67 / 255,
        );
  Color get systemFill => _dark
      ? const Color.from(
          alpha: 0.36,
          red: 120 / 255,
          green: 120 / 255,
          blue: 128 / 255,
        )
      : const Color.from(
          alpha: 0.2,
          red: 120 / 255,
          green: 120 / 255,
          blue: 128 / 255,
        );
  Color get secondarySystemFill => _dark
      ? const Color.from(
          alpha: 0.32,
          red: 120 / 255,
          green: 120 / 255,
          blue: 128 / 255,
        )
      : const Color.from(
          alpha: 0.16,
          red: 120 / 255,
          green: 120 / 255,
          blue: 128 / 255,
        );
  Color get tertiarySystemFill => _dark
      ? const Color.from(
          alpha: 0.24,
          red: 118 / 255,
          green: 118 / 255,
          blue: 128 / 255,
        )
      : const Color.from(
          alpha: 0.12,
          red: 118 / 255,
          green: 118 / 255,
          blue: 128 / 255,
        );
  Color get quaternarySystemFill => _dark
      ? const Color.from(
          alpha: 0.18,
          red: 118 / 255,
          green: 118 / 255,
          blue: 128 / 255,
        )
      : const Color.from(
          alpha: 0.08,
          red: 116 / 255,
          green: 116 / 255,
          blue: 128 / 255,
        );

  /// Alias for the tertiary label used by disabled package controls.
  Color get disabledLabel => tertiaryLabel;

  /// Named accent colors for tint pickers. Labels and fills remain separate.
  Map<String, Color> get accents => Map.unmodifiable({
    'blue': blue,
    'brown': brown,
    'cyan': cyan,
    'green': green,
    'indigo': indigo,
    'mint': mint,
    'orange': orange,
    'pink': pink,
    'purple': purple,
    'red': red,
    'teal': teal,
    'yellow': yellow,
  });
}

/// App-wide defaults. Widget arguments override these; nested themes merge.
@immutable
class LiquidPrismThemeData {
  const LiquidPrismThemeData({
    this.brightness,
    this.materialBrightness,
    this.tint,
    this.foregroundColor,
    this.glass,
    this.optics,
    this.blur,
    this.shape,
    this.motion,
    this.tabBar,
  }) : assert(blur == null || (blur >= 0 && blur <= 12));
  final Brightness? brightness;

  /// Appearance of the glass body and selected pill, independent of accents.
  /// Set explicitly when a backdrop needs the opposite native material recipe.
  final Brightness? materialBrightness;
  final Color? tint;

  /// Literal accent foreground for ordinary buttons and selected tabs.
  /// Null uses the calibrated appearance; prominent buttons retain white.
  final Color? foregroundColor;
  final Glass? glass;
  final LiquidPrismStyle? optics;

  /// Gaussian blur in logical pixels. Null retains the material default.
  final double? blur;
  final GlassShape? shape;
  final GlassMotion? motion;
  final GlassTabBarStyle? tabBar;

  LiquidPrismThemeData merge(LiquidPrismThemeData other) =>
      LiquidPrismThemeData(
        brightness: other.brightness ?? brightness,
        materialBrightness: other.materialBrightness ?? materialBrightness,
        tint: other.tint ?? tint,
        foregroundColor: other.foregroundColor ?? foregroundColor,
        glass: other.glass ?? glass,
        optics: other.optics ?? optics,
        blur: other.blur ?? blur,
        shape: other.shape ?? shape,
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
  static Brightness materialBrightnessOf(BuildContext context) =>
      of(context).materialBrightness ?? brightnessOf(context);
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
