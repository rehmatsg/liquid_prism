import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/core/prism_optics.dart';

/// Material treatment for `PrismButton`.
enum PrismButtonVariant {
  /// Standard glass treatment.
  regular,

  /// Prominent tinted glass treatment.
  prominent,
}

/// Standard control size presets.
enum PrismControlSize {
  /// Smallest control preset.
  mini,

  /// Small control preset.
  small,

  /// Standard control preset.
  regular,

  /// Large control preset.
  large,

  /// Largest control preset.
  extraLarge,
}

/// Horizontal sizing behavior for `PrismButton`.
enum PrismButtonSizing {
  /// Sizes the button to its content.
  intrinsic,

  /// Fills the available width.
  fill,
}

/// Label placement relative to a button icon.
enum PrismLabelPlacement {
  /// Places the label before the icon.
  leading,

  /// Places the label after the icon.
  trailing,

  /// Places the label above the icon.
  above,

  /// Places the label below the icon.
  below,
}

/// Reusable visual and layout overrides for `PrismButton`.
@immutable
class PrismButtonStyle {
  /// Creates a partial button style override.
  const new({
    this.variant,
    this.size,
    this.sizing,
    this.labelPlacement,
    this.spacing,
    this.alignment,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.shape,
    this.padding,
    this.minimumSize,
    this.maximumSize,
    this.textStyle,
    this.iconSize,
    this.foregroundColor,
    this.tintColor,
    this.loadingIndicator,
  }) : assert(
         blur == null || (blur >= 0 && blur <= 12),
         'Blur must be between 0 and 12.',
       ),
       assert(iconSize == null || iconSize > 0, 'Icon size must be positive.'),
       assert(spacing == null || spacing >= 0, 'Spacing must be non-negative.');

  /// Material treatment override.
  final PrismButtonVariant? variant;

  /// Control size preset override.
  final PrismControlSize? size;

  /// Horizontal sizing mode.
  final PrismButtonSizing? sizing;

  /// Label position relative to the icon.
  final PrismLabelPlacement? labelPlacement;

  /// Gap between icon and label.
  final double? spacing;

  /// Content alignment within the button.
  final AlignmentGeometry? alignment;

  /// Surface glass recipe.
  final PrismGlass? glass;

  /// Complete optical override replacing the calculated recipe.
  final PrismOptics? optics;

  /// Backdrop frost sigma override in logical pixels.
  final double? blur;

  /// Press and release spring motion.
  final PrismMotion? motion;

  /// Contour shape of the button.
  final PrismShape? shape;

  /// Internal content padding.
  final EdgeInsetsGeometry? padding;

  /// Minimum button extent.
  final Size? minimumSize;

  /// Maximum button extent.
  final Size? maximumSize;

  /// Label text style override.
  final TextStyle? textStyle;

  /// Icon size override.
  final double? iconSize;

  /// Foreground color override for text and icons.
  final Color? foregroundColor;

  /// Glass tint color override.
  final Color? tintColor;

  /// Custom widget shown while loading.
  final Widget? loadingIndicator;

  /// Returns a copy with specified fields replaced.
  PrismButtonStyle copyWith({
    PrismButtonVariant? variant,
    PrismControlSize? size,
    PrismButtonSizing? sizing,
    PrismLabelPlacement? labelPlacement,
    double? spacing,
    AlignmentGeometry? alignment,
    PrismGlass? glass,
    PrismOptics? optics,
    double? blur,
    PrismMotion? motion,
    PrismShape? shape,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? maximumSize,
    TextStyle? textStyle,
    double? iconSize,
    Color? foregroundColor,
    Color? tintColor,
    Widget? loadingIndicator,
  }) => PrismButtonStyle(
    variant: variant ?? this.variant,
    size: size ?? this.size,
    sizing: sizing ?? this.sizing,
    labelPlacement: labelPlacement ?? this.labelPlacement,
    spacing: spacing ?? this.spacing,
    alignment: alignment ?? this.alignment,
    glass: glass ?? this.glass,
    optics: optics ?? this.optics,
    blur: blur ?? this.blur,
    motion: motion ?? this.motion,
    shape: shape ?? this.shape,
    padding: padding ?? this.padding,
    minimumSize: minimumSize ?? this.minimumSize,
    maximumSize: maximumSize ?? this.maximumSize,
    textStyle: textStyle ?? this.textStyle,
    iconSize: iconSize ?? this.iconSize,
    foregroundColor: foregroundColor ?? this.foregroundColor,
    tintColor: tintColor ?? this.tintColor,
    loadingIndicator: loadingIndicator ?? this.loadingIndicator,
  );

  /// Merges non-null fields from [other] over this style.
  PrismButtonStyle merge(PrismButtonStyle? other) => other == null
      ? this
      : PrismButtonStyle(
          variant: other.variant ?? variant,
          size: other.size ?? size,
          sizing: other.sizing ?? sizing,
          labelPlacement: other.labelPlacement ?? labelPlacement,
          spacing: other.spacing ?? spacing,
          alignment: other.alignment ?? alignment,
          glass: other.glass ?? glass,
          optics: other.optics ?? optics,
          blur: other.blur ?? blur,
          motion: other.motion ?? motion,
          shape: other.shape ?? shape,
          padding: other.padding ?? padding,
          minimumSize: other.minimumSize ?? minimumSize,
          maximumSize: other.maximumSize ?? maximumSize,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          iconSize: other.iconSize ?? iconSize,
          foregroundColor: other.foregroundColor ?? foregroundColor,
          tintColor: other.tintColor ?? tintColor,
          loadingIndicator: other.loadingIndicator ?? loadingIndicator,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismButtonStyle &&
          other.variant == variant &&
          other.size == size &&
          other.sizing == sizing &&
          other.labelPlacement == labelPlacement &&
          other.spacing == spacing &&
          other.alignment == alignment &&
          other.glass == glass &&
          other.optics == optics &&
          other.blur == blur &&
          other.motion == motion &&
          other.shape == shape &&
          other.padding == padding &&
          other.minimumSize == minimumSize &&
          other.maximumSize == maximumSize &&
          other.textStyle == textStyle &&
          other.iconSize == iconSize &&
          other.foregroundColor == foregroundColor &&
          other.tintColor == tintColor &&
          other.loadingIndicator == loadingIndicator;

  @override
  int get hashCode => Object.hashAll([
    variant,
    size,
    sizing,
    labelPlacement,
    spacing,
    alignment,
    glass,
    optics,
    blur,
    motion,
    shape,
    padding,
    minimumSize,
    maximumSize,
    textStyle,
    iconSize,
    foregroundColor,
    tintColor,
    loadingIndicator,
  ]);
}
