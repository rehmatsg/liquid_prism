import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_lens_style.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/core/prism_optics.dart';

/// Visibility behavior for tab labels.
enum PrismTabLabelBehavior {
  /// Shows labels for every tab.
  always,

  /// Shows only the selected tab label.
  selected,

  /// Hides all tab labels.
  never,
}

/// Main-axis sizing behavior for `PrismTabBar`.
enum PrismTabBarSizing {
  /// Sizes the bar to fit its tabs.
  compact,

  /// Fills the available main-axis extent.
  fill,
}

/// Layout, typography, color, and lens overrides for `PrismTabBar`.
@immutable
class PrismTabBarStyle {
  /// Creates a partial tab bar style override.
  const new({
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.labelBehavior,
    this.height,
    this.padding,
    this.iconSize,
    this.badgeColor,
    this.badgeTextStyle,
    this.labelStyle,
    this.selectedColor,
    this.unselectedColor,
    this.selectionColor,
    this.selectionBlur,
    this.shape,
    this.selectionShape,
    this.haptics,
    this.sizing,
    this.minimumTabWidth,
    this.labelPadding,
    this.lens,
    this.refractContent,
    this.contentRefraction,
    this.contentDepth,
    this.rimRefraction,
  }) : assert(
         blur == null || (blur >= 0 && blur <= 12),
         'blur must be >= 0 and <= 12.',
       ),
       assert(height == null || height >= 44, 'height must be >= 44.'),
       assert(iconSize == null || iconSize > 0, 'iconSize must be > 0.'),
       assert(
         selectionBlur == null || (selectionBlur >= 0 && selectionBlur <= 12),
         'selectionBlur must be >= 0 and <= 12.',
       ),
       assert(
         minimumTabWidth == null || minimumTabWidth > 0,
         'minimumTabWidth must be > 0.',
       ),
       assert(
         labelPadding == null || labelPadding >= 0,
         'labelPadding must be >= 0.',
       ),
       assert(
         contentRefraction == null ||
             (contentRefraction >= 0 && contentRefraction <= 64),
         'contentRefraction must be >= 0 and <= 64.',
       ),
       assert(
         contentDepth == null || contentDepth > 0,
         'contentDepth must be > 0.',
       ),
       assert(
         rimRefraction == null || (rimRefraction >= 0 && rimRefraction <= 2),
         'rimRefraction must be >= 0 and <= 2.',
       );

  /// Housing surface glass recipe.
  final PrismGlass? glass;

  /// Complete optical override for the housing.
  final PrismOptics? optics;

  /// Housing backdrop frost sigma in logical pixels.
  final double? blur;

  /// Selection travel and press spring motion.
  final PrismMotion? motion;

  /// When tab text labels are displayed.
  final PrismTabLabelBehavior? labelBehavior;

  /// Tab bar height in logical pixels.
  final double? height;

  /// Default icon size.
  final double? iconSize;

  /// Inner housing padding around tabs.
  final EdgeInsetsGeometry? padding;

  /// Tab label text style override.
  final TextStyle? labelStyle;

  /// Badge background color.
  final Color? badgeColor;

  /// Badge text style.
  final TextStyle? badgeTextStyle;

  /// Foreground color for the selected tab.
  final Color? selectedColor;

  /// Foreground color for unselected tabs.
  final Color? unselectedColor;

  /// Fill color of the resting selection pill.
  final Color? selectionColor;

  /// Independent backdrop blur sigma for the resting selection pill.
  final double? selectionBlur;

  /// Contour shape of the bar housing.
  final PrismShape? shape;

  /// Contour shape of the selection pill.
  final PrismShape? selectionShape;

  /// Whether selection haptics are enabled.
  final bool? haptics;

  /// Compact or full-width sizing behavior.
  final PrismTabBarSizing? sizing;

  /// Minimum tab slot width before label measurement.
  final double? minimumTabWidth;

  /// Extra horizontal padding around measured tab labels.
  final double? labelPadding;

  /// Lifted selection lens overrides.
  final PrismLensStyle? lens;

  /// Whether tab icons and labels refract near the held pill rim.
  final bool? refractContent;

  /// Foreground refraction displacement magnitude.
  final double? contentRefraction;

  /// Foreground refraction rim depth.
  final double? contentDepth;

  /// Multiplier for the held pill's rim chromatic fringe and glint.
  final double? rimRefraction;

  /// Returns a copy with specified fields replaced.
  PrismTabBarStyle copyWith({
    PrismGlass? glass,
    PrismOptics? optics,
    double? blur,
    PrismMotion? motion,
    PrismTabLabelBehavior? labelBehavior,
    double? height,
    EdgeInsetsGeometry? padding,
    double? iconSize,
    Color? badgeColor,
    TextStyle? badgeTextStyle,
    TextStyle? labelStyle,
    Color? selectedColor,
    Color? unselectedColor,
    Color? selectionColor,
    double? selectionBlur,
    PrismShape? shape,
    PrismShape? selectionShape,
    bool? haptics,
    PrismTabBarSizing? sizing,
    double? minimumTabWidth,
    double? labelPadding,
    PrismLensStyle? lens,
    bool? refractContent,
    double? contentRefraction,
    double? contentDepth,
    double? rimRefraction,
  }) => PrismTabBarStyle(
    glass: glass ?? this.glass,
    optics: optics ?? this.optics,
    blur: blur ?? this.blur,
    motion: motion ?? this.motion,
    labelBehavior: labelBehavior ?? this.labelBehavior,
    height: height ?? this.height,
    padding: padding ?? this.padding,
    iconSize: iconSize ?? this.iconSize,
    badgeColor: badgeColor ?? this.badgeColor,
    badgeTextStyle: badgeTextStyle ?? this.badgeTextStyle,
    labelStyle: labelStyle ?? this.labelStyle,
    selectedColor: selectedColor ?? this.selectedColor,
    unselectedColor: unselectedColor ?? this.unselectedColor,
    selectionColor: selectionColor ?? this.selectionColor,
    selectionBlur: selectionBlur ?? this.selectionBlur,
    shape: shape ?? this.shape,
    selectionShape: selectionShape ?? this.selectionShape,
    haptics: haptics ?? this.haptics,
    sizing: sizing ?? this.sizing,
    minimumTabWidth: minimumTabWidth ?? this.minimumTabWidth,
    labelPadding: labelPadding ?? this.labelPadding,
    lens: lens ?? this.lens,
    refractContent: refractContent ?? this.refractContent,
    contentRefraction: contentRefraction ?? this.contentRefraction,
    contentDepth: contentDepth ?? this.contentDepth,
    rimRefraction: rimRefraction ?? this.rimRefraction,
  );

  /// Merges non-null fields from [other] over this style.
  PrismTabBarStyle merge(PrismTabBarStyle? other) => other == null
      ? this
      : PrismTabBarStyle(
          glass: other.glass ?? glass,
          optics: other.optics ?? optics,
          blur: other.blur ?? blur,
          motion: other.motion ?? motion,
          labelBehavior: other.labelBehavior ?? labelBehavior,
          height: other.height ?? height,
          padding: other.padding ?? padding,
          iconSize: other.iconSize ?? iconSize,
          badgeColor: other.badgeColor ?? badgeColor,
          badgeTextStyle:
              badgeTextStyle?.merge(other.badgeTextStyle) ??
              other.badgeTextStyle,
          labelStyle: labelStyle?.merge(other.labelStyle) ?? other.labelStyle,
          selectedColor: other.selectedColor ?? selectedColor,
          unselectedColor: other.unselectedColor ?? unselectedColor,
          selectionColor: other.selectionColor ?? selectionColor,
          selectionBlur: other.selectionBlur ?? selectionBlur,
          shape: other.shape ?? shape,
          selectionShape: other.selectionShape ?? selectionShape,
          haptics: other.haptics ?? haptics,
          sizing: other.sizing ?? sizing,
          minimumTabWidth: other.minimumTabWidth ?? minimumTabWidth,
          labelPadding: other.labelPadding ?? labelPadding,
          lens: lens == null && other.lens == null
              ? null
              : (lens ?? const PrismLensStyle()).merge(other.lens),
          refractContent: other.refractContent ?? refractContent,
          contentRefraction: other.contentRefraction ?? contentRefraction,
          contentDepth: other.contentDepth ?? contentDepth,
          rimRefraction: other.rimRefraction ?? rimRefraction,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismTabBarStyle &&
          other.glass == glass &&
          other.optics == optics &&
          other.blur == blur &&
          other.motion == motion &&
          other.labelBehavior == labelBehavior &&
          other.height == height &&
          other.padding == padding &&
          other.iconSize == iconSize &&
          other.badgeColor == badgeColor &&
          other.badgeTextStyle == badgeTextStyle &&
          other.labelStyle == labelStyle &&
          other.selectedColor == selectedColor &&
          other.unselectedColor == unselectedColor &&
          other.selectionColor == selectionColor &&
          other.selectionBlur == selectionBlur &&
          other.shape == shape &&
          other.selectionShape == selectionShape &&
          other.haptics == haptics &&
          other.sizing == sizing &&
          other.minimumTabWidth == minimumTabWidth &&
          other.labelPadding == labelPadding &&
          other.lens == lens &&
          other.refractContent == refractContent &&
          other.contentRefraction == contentRefraction &&
          other.contentDepth == contentDepth &&
          other.rimRefraction == rimRefraction;

  @override
  int get hashCode => Object.hashAll([
    glass,
    optics,
    blur,
    motion,
    labelBehavior,
    height,
    padding,
    iconSize,
    badgeColor,
    badgeTextStyle,
    labelStyle,
    selectedColor,
    unselectedColor,
    selectionColor,
    selectionBlur,
    shape,
    selectionShape,
    haptics,
    sizing,
    minimumTabWidth,
    labelPadding,
    lens,
    refractContent,
    contentRefraction,
    contentDepth,
    rimRefraction,
  ]);
}
