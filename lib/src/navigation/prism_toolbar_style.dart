import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/core/prism_optics.dart';
import 'package:liquid_prism/src/rendering/prism_transition.dart';

/// Standard toolbar placement presets.
enum PrismToolbarSize {
  /// Uses navigation toolbar sizing.
  navigation,

  /// Uses bottom toolbar sizing.
  bottom,
}

/// Shared toolbar appearance, spacing, and back-button defaults.
@immutable
class PrismToolbarStyle {
  /// Creates a partial toolbar style override.
  const new({
    this.size,
    this.height,
    this.inset,
    this.spacing,
    this.iconSize,
    this.textStyle,
    this.badgeColor,
    this.badgeTextStyle,
    this.foregroundColor,
    this.pressedColor,
    this.shape,
    this.itemShape,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.itemTransition,
    this.itemTransitionStyle,
    this.groupSpacing,
    this.backIcon,
    this.closeIcon,
    this.backIconShift,
    this.backIconMirrors,
  }) : assert(height == null || height >= 44, 'height must be >= 44.'),
       assert(inset == null || inset >= 0, 'inset must be >= 0.'),
       assert(spacing == null || spacing >= 0, 'spacing must be >= 0.'),
       assert(iconSize == null || iconSize > 0, 'iconSize must be > 0.'),
       assert(
         blur == null || (blur >= 0 && blur <= 12),
         'blur must be >= 0 and <= 12.',
       ),
       assert(
         groupSpacing == null || groupSpacing >= 0,
         'groupSpacing must be >= 0.',
       ),
       assert(
         backIconShift == null || backIconShift >= 0,
         'backIconShift must be >= 0.',
       );

  /// Toolbar sizing preset.
  final PrismToolbarSize? size;

  /// Capsule height in logical pixels.
  final double? height;

  /// Inner padding around items in a capsule.
  final double? inset;

  /// Gap between adjacent items in a capsule.
  final double? spacing;

  /// Default toolbar icon size.
  final double? iconSize;

  /// Default text style for label toolbar items.
  final TextStyle? textStyle;

  /// Default foreground color for toolbar items.
  final Color? foregroundColor;

  /// Badge background color.
  final Color? badgeColor;

  /// Badge text style.
  final TextStyle? badgeTextStyle;

  /// Optional fill painted while a toolbar item is pressed.
  final Color? pressedColor;

  /// Contour shape of the toolbar capsule.
  final PrismShape? shape;

  /// Contour shape of individual toolbar item press regions.
  final PrismShape? itemShape;

  /// Surface glass recipe.
  final PrismGlass? glass;

  /// Complete optical override replacing the calculated recipe.
  final PrismOptics? optics;

  /// Backdrop frost sigma override in logical pixels.
  final double? blur;

  /// Press and release spring motion.
  final PrismMotion? motion;

  /// Transition used when toolbar items enter or leave a group.
  final PrismTransition? itemTransition;

  /// Timing overrides for [itemTransition].
  final PrismTransitionStyle? itemTransitionStyle;

  /// Gap between separate capsules in a toolbar.
  final double? groupSpacing;

  /// Custom glyph for `PrismBackButton` in back mode.
  final Widget? backIcon;

  /// Custom glyph for `PrismBackButton` in close mode.
  final Widget? closeIcon;

  /// Optical horizontal shift applied to the back glyph.
  final double? backIconShift;

  /// Whether [backIconShift] mirrors in RTL layouts.
  final bool? backIconMirrors;

  /// Returns a copy with specified fields replaced.
  PrismToolbarStyle copyWith({
    PrismToolbarSize? size,
    double? height,
    double? inset,
    double? spacing,
    double? iconSize,
    TextStyle? textStyle,
    Color? badgeColor,
    TextStyle? badgeTextStyle,
    Color? foregroundColor,
    Color? pressedColor,
    PrismShape? shape,
    PrismShape? itemShape,
    PrismGlass? glass,
    PrismOptics? optics,
    double? blur,
    PrismMotion? motion,
    PrismTransition? itemTransition,
    PrismTransitionStyle? itemTransitionStyle,
    double? groupSpacing,
    Widget? backIcon,
    Widget? closeIcon,
    double? backIconShift,
    bool? backIconMirrors,
  }) => PrismToolbarStyle(
    size: size ?? this.size,
    height: height ?? this.height,
    inset: inset ?? this.inset,
    spacing: spacing ?? this.spacing,
    iconSize: iconSize ?? this.iconSize,
    textStyle: textStyle ?? this.textStyle,
    badgeColor: badgeColor ?? this.badgeColor,
    badgeTextStyle: badgeTextStyle ?? this.badgeTextStyle,
    foregroundColor: foregroundColor ?? this.foregroundColor,
    pressedColor: pressedColor ?? this.pressedColor,
    shape: shape ?? this.shape,
    itemShape: itemShape ?? this.itemShape,
    glass: glass ?? this.glass,
    optics: optics ?? this.optics,
    blur: blur ?? this.blur,
    motion: motion ?? this.motion,
    itemTransition: itemTransition ?? this.itemTransition,
    itemTransitionStyle: itemTransitionStyle ?? this.itemTransitionStyle,
    groupSpacing: groupSpacing ?? this.groupSpacing,
    backIcon: backIcon ?? this.backIcon,
    closeIcon: closeIcon ?? this.closeIcon,
    backIconShift: backIconShift ?? this.backIconShift,
    backIconMirrors: backIconMirrors ?? this.backIconMirrors,
  );

  /// Merges non-null fields from [other] over this style.
  PrismToolbarStyle merge(PrismToolbarStyle? other) => other == null
      ? this
      : PrismToolbarStyle(
          size: other.size ?? size,
          height: other.height ?? height,
          inset: other.inset ?? inset,
          spacing: other.spacing ?? spacing,
          iconSize: other.iconSize ?? iconSize,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          badgeColor: other.badgeColor ?? badgeColor,
          badgeTextStyle:
              badgeTextStyle?.merge(other.badgeTextStyle) ??
              other.badgeTextStyle,
          foregroundColor: other.foregroundColor ?? foregroundColor,
          pressedColor: other.pressedColor ?? pressedColor,
          shape: other.shape ?? shape,
          itemShape: other.itemShape ?? itemShape,
          glass: other.glass ?? glass,
          optics: other.optics ?? optics,
          blur: other.blur ?? blur,
          motion: other.motion ?? motion,
          itemTransition: other.itemTransition ?? itemTransition,
          itemTransitionStyle:
              itemTransitionStyle == null && other.itemTransitionStyle == null
              ? null
              : (itemTransitionStyle ?? const PrismTransitionStyle()).merge(
                  other.itemTransitionStyle,
                ),
          groupSpacing: other.groupSpacing ?? groupSpacing,
          backIcon: other.backIcon ?? backIcon,
          closeIcon: other.closeIcon ?? closeIcon,
          backIconShift: other.backIconShift ?? backIconShift,
          backIconMirrors: other.backIconMirrors ?? backIconMirrors,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismToolbarStyle &&
          other.size == size &&
          other.height == height &&
          other.inset == inset &&
          other.spacing == spacing &&
          other.iconSize == iconSize &&
          other.textStyle == textStyle &&
          other.badgeColor == badgeColor &&
          other.badgeTextStyle == badgeTextStyle &&
          other.foregroundColor == foregroundColor &&
          other.pressedColor == pressedColor &&
          other.shape == shape &&
          other.itemShape == itemShape &&
          other.glass == glass &&
          other.optics == optics &&
          other.blur == blur &&
          other.motion == motion &&
          other.itemTransition == itemTransition &&
          other.itemTransitionStyle == itemTransitionStyle &&
          other.groupSpacing == groupSpacing &&
          other.backIcon == backIcon &&
          other.closeIcon == closeIcon &&
          other.backIconShift == backIconShift &&
          other.backIconMirrors == backIconMirrors;

  @override
  int get hashCode => Object.hashAll([
    size,
    height,
    inset,
    spacing,
    iconSize,
    textStyle,
    badgeColor,
    badgeTextStyle,
    foregroundColor,
    pressedColor,
    shape,
    itemShape,
    glass,
    optics,
    blur,
    motion,
    itemTransition,
    itemTransitionStyle,
    groupSpacing,
    backIcon,
    closeIcon,
    backIconShift,
    backIconMirrors,
  ]);
}
