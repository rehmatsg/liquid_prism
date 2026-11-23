import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/controls/prism_button_style.dart';
import 'package:liquid_prism/src/controls/prism_search_style.dart';
import 'package:liquid_prism/src/controls/prism_segmented_style.dart';
import 'package:liquid_prism/src/controls/prism_slider_style.dart';
import 'package:liquid_prism/src/controls/prism_switch_style.dart';
import 'package:liquid_prism/src/core/prism_colors.dart';
import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_haptics.dart';
import 'package:liquid_prism/src/core/prism_lens_style.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/core/prism_optics.dart';
import 'package:liquid_prism/src/navigation/prism_navigation_bar_style.dart';
import 'package:liquid_prism/src/navigation/prism_scaffold_style.dart';
import 'package:liquid_prism/src/navigation/prism_scroll_edge_style.dart';
import 'package:liquid_prism/src/navigation/prism_tab_bar_style.dart';
import 'package:liquid_prism/src/navigation/prism_toolbar_style.dart';
import 'package:liquid_prism/src/rendering/prism_transition.dart';

/// App-wide glass, motion, and component style defaults.
@immutable
class PrismThemeData {
  /// Creates theme defaults; null fields inherit or fall back to native values.
  const new({
    this.haptics,
    this.brightness,
    this.materialBrightness,
    this.tint,
    this.foregroundColor,
    this.glass,
    this.optics,
    this.blur,
    this.refraction,
    this.glassTint,
    this.shadow,
    this.shape,
    this.motion,
    this.navigationBar,
    this.scaffold,
    this.tabBar,
    this.lens,
    this.button,
    this.switchStyle,
    this.slider,
    this.segmentedControl,
    this.toolbar,
    this.search,
    this.controlMotion,
    this.transition,
    this.scrollEdge,
  }) : assert(
         blur == null || (blur >= 0 && blur <= 12),
         'blur must be between 0 and 12.',
       ),
       assert(
         refraction == null || refraction >= 0,
         'refraction must be non-negative.',
       ),
       assert(
         glassTint == null || (glassTint >= 0 && glassTint <= 1),
         'glassTint must be between 0 and 1.',
       );

  /// Custom haptic feedback hook.
  final PrismHaptics? haptics;

  /// Appearance brightness for semantic colors and surfaces.
  final Brightness? brightness;

  /// Independent material appearance brightness.
  final Brightness? materialBrightness;

  /// Primary accent tint color.
  final Color? tint;

  /// Literal accent foreground color for controls and selected tabs.
  final Color? foregroundColor;

  /// Default glass material recipe.
  final PrismGlass? glass;

  /// Default optical parameter override.
  final PrismOptics? optics;

  /// Default backdrop blur sigma in logical pixels.
  final double? blur;

  /// Default rim refraction displacement in logical pixels.
  final double? refraction;

  /// Glass tint amount in `[0, 1]`; null follows the device setting.
  final double? glassTint;

  /// Whether exterior and inset material shadows are painted.
  final bool? shadow;

  /// Default surface contour shape.
  final PrismShape? shape;

  /// Default spatial motion for buttons and navigation controls.
  final PrismMotion? motion;

  /// Default navigation bar styling.
  final PrismNavigationBarStyle? navigationBar;

  /// Default scaffold chrome placement styling.
  final PrismScaffoldStyle? scaffold;

  /// Default tab bar styling.
  final PrismTabBarStyle? tabBar;

  /// Shared lifted-lens styling for interactive controls.
  final PrismLensStyle? lens;

  /// Default button styling.
  final PrismButtonStyle? button;

  /// Default switch styling.
  final PrismSwitchStyle? switchStyle;

  /// Default slider styling.
  final PrismSliderStyle? slider;

  /// Default segmented control styling.
  final PrismSegmentedStyle? segmentedControl;

  /// Default toolbar styling.
  final PrismToolbarStyle? toolbar;

  /// Default search field styling.
  final PrismSearchStyle? search;

  /// Default motion overrides for small controls.
  final PrismControlMotion? controlMotion;

  /// Default enter/exit transition styling for [PrismVisibility].
  final PrismTransitionStyle? transition;

  /// Default scroll edge styling.
  final PrismScrollEdgeStyle? scrollEdge;

  /// Returns a copy with specified fields replaced.
  PrismThemeData copyWith({
    PrismHaptics? haptics,
    Brightness? brightness,
    Brightness? materialBrightness,
    Color? tint,
    Color? foregroundColor,
    PrismGlass? glass,
    PrismOptics? optics,
    double? blur,
    double? refraction,
    double? glassTint,
    bool? shadow,
    PrismShape? shape,
    PrismMotion? motion,
    PrismNavigationBarStyle? navigationBar,
    PrismScaffoldStyle? scaffold,
    PrismTabBarStyle? tabBar,
    PrismLensStyle? lens,
    PrismButtonStyle? button,
    PrismSwitchStyle? switchStyle,
    PrismSliderStyle? slider,
    PrismSegmentedStyle? segmentedControl,
    PrismToolbarStyle? toolbar,
    PrismSearchStyle? search,
    PrismControlMotion? controlMotion,
    PrismTransitionStyle? transition,
    PrismScrollEdgeStyle? scrollEdge,
  }) => PrismThemeData(
    haptics: haptics ?? this.haptics,
    brightness: brightness ?? this.brightness,
    materialBrightness: materialBrightness ?? this.materialBrightness,
    tint: tint ?? this.tint,
    foregroundColor: foregroundColor ?? this.foregroundColor,
    glass: glass ?? this.glass,
    optics: optics ?? this.optics,
    blur: blur ?? this.blur,
    refraction: refraction ?? this.refraction,
    glassTint: glassTint ?? this.glassTint,
    shadow: shadow ?? this.shadow,
    shape: shape ?? this.shape,
    motion: motion ?? this.motion,
    navigationBar: navigationBar ?? this.navigationBar,
    scaffold: scaffold ?? this.scaffold,
    tabBar: tabBar ?? this.tabBar,
    lens: lens ?? this.lens,
    button: button ?? this.button,
    switchStyle: switchStyle ?? this.switchStyle,
    slider: slider ?? this.slider,
    segmentedControl: segmentedControl ?? this.segmentedControl,
    toolbar: toolbar ?? this.toolbar,
    search: search ?? this.search,
    controlMotion: controlMotion ?? this.controlMotion,
    transition: transition ?? this.transition,
    scrollEdge: scrollEdge ?? this.scrollEdge,
  );

  /// Merges non-null fields from [other] over this theme data.
  PrismThemeData merge(PrismThemeData other) => PrismThemeData(
    haptics: other.haptics ?? haptics,
    brightness: other.brightness ?? brightness,
    materialBrightness: other.materialBrightness ?? materialBrightness,
    tint: other.tint ?? tint,
    foregroundColor: other.foregroundColor ?? foregroundColor,
    glass: other.glass ?? glass,
    optics: other.optics ?? optics,
    blur: other.blur ?? blur,
    refraction: other.refraction ?? refraction,
    glassTint: other.glassTint ?? glassTint,
    shadow: other.shadow ?? shadow,
    shape: other.shape ?? shape,
    motion: other.motion ?? motion,
    navigationBar: navigationBar == null && other.navigationBar == null
        ? null
        : (navigationBar ?? const PrismNavigationBarStyle()).merge(
            other.navigationBar,
          ),
    scaffold: scaffold == null && other.scaffold == null
        ? null
        : (scaffold ?? const PrismScaffoldStyle()).merge(other.scaffold),
    tabBar: tabBar == null && other.tabBar == null
        ? null
        : (tabBar ?? const PrismTabBarStyle()).merge(other.tabBar),
    lens: lens == null && other.lens == null
        ? null
        : (lens ?? const PrismLensStyle()).merge(other.lens),
    button: button == null && other.button == null
        ? null
        : (button ?? const PrismButtonStyle()).merge(other.button),
    switchStyle: switchStyle == null && other.switchStyle == null
        ? null
        : (switchStyle ?? const PrismSwitchStyle()).merge(other.switchStyle),
    slider: slider == null && other.slider == null
        ? null
        : (slider ?? const PrismSliderStyle()).merge(other.slider),
    segmentedControl: segmentedControl == null && other.segmentedControl == null
        ? null
        : (segmentedControl ?? const PrismSegmentedStyle()).merge(
            other.segmentedControl,
          ),
    toolbar: toolbar == null && other.toolbar == null
        ? null
        : (toolbar ?? const PrismToolbarStyle()).merge(other.toolbar),
    search: search == null && other.search == null
        ? null
        : (search ?? const PrismSearchStyle()).merge(other.search),
    controlMotion: controlMotion == null && other.controlMotion == null
        ? null
        : (controlMotion ?? const PrismControlMotion()).merge(
            other.controlMotion,
          ),
    transition: transition == null && other.transition == null
        ? null
        : (transition ?? const PrismTransitionStyle()).merge(other.transition),
    scrollEdge: scrollEdge == null && other.scrollEdge == null
        ? null
        : (scrollEdge ?? const PrismScrollEdgeStyle()).merge(other.scrollEdge),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismThemeData &&
          other.haptics == haptics &&
          other.brightness == brightness &&
          other.materialBrightness == materialBrightness &&
          other.tint == tint &&
          other.foregroundColor == foregroundColor &&
          other.glass == glass &&
          other.optics == optics &&
          other.blur == blur &&
          other.refraction == refraction &&
          other.glassTint == glassTint &&
          other.shadow == shadow &&
          other.shape == shape &&
          other.motion == motion &&
          other.navigationBar == navigationBar &&
          other.scaffold == scaffold &&
          other.tabBar == tabBar &&
          other.lens == lens &&
          other.button == button &&
          other.switchStyle == switchStyle &&
          other.slider == slider &&
          other.segmentedControl == segmentedControl &&
          other.toolbar == toolbar &&
          other.search == search &&
          other.controlMotion == controlMotion &&
          other.transition == transition &&
          other.scrollEdge == scrollEdge;

  @override
  int get hashCode => Object.hashAll([
    haptics,
    brightness,
    materialBrightness,
    tint,
    foregroundColor,
    glass,
    optics,
    blur,
    refraction,
    glassTint,
    shadow,
    shape,
    motion,
    navigationBar,
    scaffold,
    tabBar,
    lens,
    button,
    switchStyle,
    slider,
    segmentedControl,
    toolbar,
    search,
    controlMotion,
    transition,
    scrollEdge,
  ]);
}

/// Provides [PrismThemeData] defaults to descendant Prism widgets.
class PrismTheme extends StatelessWidget {
  /// Creates a theme scope; set [inherit] to false to reset ancestor values.
  const new({
    required this.child,
    super.key,
    this.brightness,
    this.tint,
    this.data = const PrismThemeData(),
    this.inherit = true,
  });

  /// Optional brightness override merged above [data].
  final Brightness? brightness;

  /// Optional accent tint override merged above [data].
  final Color? tint;

  /// Theme defaults applied to this subtree.
  final PrismThemeData data;

  /// Whether unspecified fields inherit from an ancestor [PrismTheme].
  final bool inherit;

  /// Subtree that receives the resolved theme.
  final Widget child;

  /// Returns the resolved [PrismThemeData] for [context].
  static PrismThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PrismThemeScope>()?.data ??
      const PrismThemeData();

  /// Returns the active appearance brightness for [context].
  static Brightness brightnessOf(BuildContext context) =>
      of(context).brightness ?? MediaQuery.platformBrightnessOf(context);

  /// Returns the active glass material brightness for [context].
  static Brightness materialBrightnessOf(BuildContext context) =>
      of(context).materialBrightness ?? brightnessOf(context);

  /// Returns the active [PrismColors] palette for [context].
  static PrismColors colorsOf(BuildContext context) =>
      PrismColors(brightnessOf(context));

  /// Returns the active accent tint color for [context].
  static Color tintOf(BuildContext context) =>
      of(context).tint ?? colorsOf(context).blue;

  @override
  Widget build(BuildContext context) => _PrismThemeScope(
    data: (inherit ? of(context) : const PrismThemeData())
        .merge(data)
        .merge(PrismThemeData(brightness: brightness, tint: tint)),
    child: child,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<Brightness>('brightness', brightness))
      ..add(ColorProperty('tint', tint))
      ..add(DiagnosticsProperty<PrismThemeData>('data', data))
      ..add(FlagProperty('inherit', value: inherit, ifTrue: 'inherit'));
  }
}

class _PrismThemeScope extends InheritedWidget {
  const new({required this.data, required super.child});

  final PrismThemeData data;

  @override
  bool updateShouldNotify(_PrismThemeScope oldWidget) => data != oldWidget.data;
}
