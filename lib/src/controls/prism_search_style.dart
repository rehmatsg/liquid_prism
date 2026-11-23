import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/core/prism_optics.dart';

/// Visibility behavior for a search field's cancel button.
enum PrismSearchCancelVisibility {
  /// Shows the cancel button while the editor has focus.
  focused,

  /// Shows the cancel button regardless of focus.
  always,
}

/// Visual and layout overrides for `PrismSearchField`.
@immutable
class PrismSearchStyle {
  /// Creates a partial search field style override.
  const new({
    this.height,
    this.restingInset,
    this.showCancelButton,
    this.cancelVisibility,
    this.showClearButton,
    this.textStyle,
    this.placeholderStyle,
    this.iconColor,
    this.cursorColor,
    this.clearColor,
    this.iconSize,
    this.padding,
    this.prefixPadding,
    this.clearWidth,
    this.cancelWidth,
    this.cancelSpacing,
    this.shape,
    this.glass,
    this.optics,
    this.blur,
    this.focusSpring,
    this.cancelSpring,
  }) : assert(height == null || height >= 44, 'Height must be at least 44.'),
       assert(
         restingInset == null || restingInset >= 0,
         'Resting inset must be non-negative.',
       ),
       assert(iconSize == null || iconSize > 0, 'Icon size must be positive.'),
       assert(
         clearWidth == null || clearWidth > 0,
         'Clear width must be positive.',
       ),
       assert(
         cancelWidth == null || cancelWidth >= 44,
         'Cancel width must be at least 44.',
       ),
       assert(
         cancelSpacing == null || cancelSpacing >= 0,
         'Cancel spacing must be non-negative.',
       ),
       assert(
         blur == null || (blur >= 0 && blur <= 12),
         'Blur must be between 0 and 12.',
       );

  /// Capsule height in logical pixels.
  final double? height;

  /// Horizontal inset applied while unfocused.
  final double? restingInset;

  /// Whether the cancel button can appear.
  final bool? showCancelButton;

  /// When the cancel button is displayed.
  final PrismSearchCancelVisibility? cancelVisibility;

  /// Whether the clear button is shown when text is non-empty.
  final bool? showClearButton;

  /// Input text style override.
  final TextStyle? textStyle;

  /// Placeholder text style override.
  final TextStyle? placeholderStyle;

  /// Leading search icon color.
  final Color? iconColor;

  /// Text insertion cursor color.
  final Color? cursorColor;

  /// Clear button icon color.
  final Color? clearColor;

  /// Leading search icon size.
  final double? iconSize;

  /// Editor padding between prefix and suffix.
  final EdgeInsetsGeometry? padding;

  /// Padding around the default search icon.
  final EdgeInsetsGeometry? prefixPadding;

  /// Clear button width.
  final double? clearWidth;

  /// Cancel button width.
  final double? cancelWidth;

  /// Gap between search capsule and cancel button.
  final double? cancelSpacing;

  /// Contour shape of the search capsule.
  final PrismShape? shape;

  /// Surface glass recipe.
  final PrismGlass? glass;

  /// Complete optical override replacing the calculated recipe.
  final PrismOptics? optics;

  /// Backdrop frost sigma override in logical pixels.
  final double? blur;

  /// Spring driving field focus resize.
  final PrismSpring? focusSpring;

  /// Spring driving cancel button entrance.
  final PrismSpring? cancelSpring;

  /// Returns a copy with specified fields replaced.
  PrismSearchStyle copyWith({
    double? height,
    double? restingInset,
    bool? showCancelButton,
    PrismSearchCancelVisibility? cancelVisibility,
    bool? showClearButton,
    TextStyle? textStyle,
    TextStyle? placeholderStyle,
    Color? iconColor,
    Color? cursorColor,
    Color? clearColor,
    double? iconSize,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? prefixPadding,
    double? clearWidth,
    double? cancelWidth,
    double? cancelSpacing,
    PrismShape? shape,
    PrismGlass? glass,
    PrismOptics? optics,
    double? blur,
    PrismSpring? focusSpring,
    PrismSpring? cancelSpring,
  }) => PrismSearchStyle(
    height: height ?? this.height,
    restingInset: restingInset ?? this.restingInset,
    showCancelButton: showCancelButton ?? this.showCancelButton,
    cancelVisibility: cancelVisibility ?? this.cancelVisibility,
    showClearButton: showClearButton ?? this.showClearButton,
    textStyle: textStyle ?? this.textStyle,
    placeholderStyle: placeholderStyle ?? this.placeholderStyle,
    iconColor: iconColor ?? this.iconColor,
    cursorColor: cursorColor ?? this.cursorColor,
    clearColor: clearColor ?? this.clearColor,
    iconSize: iconSize ?? this.iconSize,
    padding: padding ?? this.padding,
    prefixPadding: prefixPadding ?? this.prefixPadding,
    clearWidth: clearWidth ?? this.clearWidth,
    cancelWidth: cancelWidth ?? this.cancelWidth,
    cancelSpacing: cancelSpacing ?? this.cancelSpacing,
    shape: shape ?? this.shape,
    glass: glass ?? this.glass,
    optics: optics ?? this.optics,
    blur: blur ?? this.blur,
    focusSpring: focusSpring ?? this.focusSpring,
    cancelSpring: cancelSpring ?? this.cancelSpring,
  );

  /// Merges non-null fields from [other] over this style.
  PrismSearchStyle merge(PrismSearchStyle? other) => other == null
      ? this
      : PrismSearchStyle(
          height: other.height ?? height,
          restingInset: other.restingInset ?? restingInset,
          showCancelButton: other.showCancelButton ?? showCancelButton,
          cancelVisibility: other.cancelVisibility ?? cancelVisibility,
          showClearButton: other.showClearButton ?? showClearButton,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          placeholderStyle:
              placeholderStyle?.merge(other.placeholderStyle) ??
              other.placeholderStyle,
          iconColor: other.iconColor ?? iconColor,
          cursorColor: other.cursorColor ?? cursorColor,
          clearColor: other.clearColor ?? clearColor,
          iconSize: other.iconSize ?? iconSize,
          padding: other.padding ?? padding,
          prefixPadding: other.prefixPadding ?? prefixPadding,
          clearWidth: other.clearWidth ?? clearWidth,
          cancelWidth: other.cancelWidth ?? cancelWidth,
          cancelSpacing: other.cancelSpacing ?? cancelSpacing,
          shape: other.shape ?? shape,
          glass: other.glass ?? glass,
          optics: other.optics ?? optics,
          blur: other.blur ?? blur,
          focusSpring: other.focusSpring ?? focusSpring,
          cancelSpring: other.cancelSpring ?? cancelSpring,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismSearchStyle &&
          other.height == height &&
          other.restingInset == restingInset &&
          other.showCancelButton == showCancelButton &&
          other.cancelVisibility == cancelVisibility &&
          other.showClearButton == showClearButton &&
          other.textStyle == textStyle &&
          other.placeholderStyle == placeholderStyle &&
          other.iconColor == iconColor &&
          other.cursorColor == cursorColor &&
          other.clearColor == clearColor &&
          other.iconSize == iconSize &&
          other.padding == padding &&
          other.prefixPadding == prefixPadding &&
          other.clearWidth == clearWidth &&
          other.cancelWidth == cancelWidth &&
          other.cancelSpacing == cancelSpacing &&
          other.shape == shape &&
          other.glass == glass &&
          other.optics == optics &&
          other.blur == blur &&
          other.focusSpring == focusSpring &&
          other.cancelSpring == cancelSpring;

  @override
  int get hashCode => Object.hashAll([
    height,
    restingInset,
    showCancelButton,
    cancelVisibility,
    showClearButton,
    textStyle,
    placeholderStyle,
    iconColor,
    cursorColor,
    clearColor,
    iconSize,
    padding,
    prefixPadding,
    clearWidth,
    cancelWidth,
    cancelSpacing,
    shape,
    glass,
    optics,
    blur,
    focusSpring,
    cancelSpring,
  ]);
}
