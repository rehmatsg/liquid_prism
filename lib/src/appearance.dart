import 'package:flutter/widgets.dart';

import 'glass_transition.dart';
import 'material.dart';
import 'motion.dart';
import 'style.dart';

/// Native button material treatments.
enum GlassButtonStyle { glass, glassProminent }

/// Native toolbar placement presets.
enum GlassToolbarSize { navigation, bottom }

// Nullable fields mean inherit. copyWith keeps null arguments; merge fills only
// the supplied fields. Widget resolution supplies the captured native defaults.

/// Optics and elevation shared by lifted handles and selection pills.
///
/// Unspecified fields inherit the surrounding theme, then native defaults.
@immutable
class GlassLensStyle {
  const GlassLensStyle({
    this.glass,
    this.optics,
    this.blur,
    this.shape,
    this.minifyUnderlay,
    this.shadow,
    this.scaleShadows,
    this.shadowOpacity,
    this.shadowBlur,
    this.shadowOffset,
    this.ringOpacity,
    this.ringBlur,
    this.ringWidth,
    this.ringOffset,
  }) : assert(blur == null || blur >= 0 && blur <= 12),
       assert(
         shadowOpacity == null || shadowOpacity >= 0 && shadowOpacity <= 1,
       ),
       assert(shadowBlur == null || shadowBlur >= 0),
       assert(ringOpacity == null || ringOpacity >= 0 && ringOpacity <= 1),
       assert(ringBlur == null || ringBlur >= 0),
       assert(ringWidth == null || ringWidth >= 0);
  final Glass? glass;

  /// A complete optical packet; supplied values replace the calculated recipe.
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassShape? shape;

  /// Whether the component visible through the lens shrinks. Slider defaults false.
  final bool? minifyUnderlay;

  /// Paint resting and lifted shadows. Set false to disable both.
  final bool? shadow;

  /// Scale shadow blur, offsets and ring width with lens height. Defaults true.
  final bool? scaleShadows;
  final double? shadowOpacity;
  final double? shadowBlur;
  final Offset? shadowOffset;
  final double? ringOpacity;
  final double? ringBlur;
  final double? ringWidth;
  final Offset? ringOffset;

  /// Keep existing fields when an argument is null.
  GlassLensStyle copyWith({
    Glass? glass,
    LiquidPrismStyle? optics,
    double? blur,
    GlassShape? shape,
    bool? minifyUnderlay,
    bool? shadow,
    bool? scaleShadows,
    double? shadowOpacity,
    double? shadowBlur,
    Offset? shadowOffset,
    double? ringOpacity,
    double? ringBlur,
    double? ringWidth,
    Offset? ringOffset,
  }) => GlassLensStyle(
    glass: glass ?? this.glass,
    optics: optics ?? this.optics,
    blur: blur ?? this.blur,
    shape: shape ?? this.shape,
    minifyUnderlay: minifyUnderlay ?? this.minifyUnderlay,
    shadow: shadow ?? this.shadow,
    scaleShadows: scaleShadows ?? this.scaleShadows,
    shadowOpacity: shadowOpacity ?? this.shadowOpacity,
    shadowBlur: shadowBlur ?? this.shadowBlur,
    shadowOffset: shadowOffset ?? this.shadowOffset,
    ringOpacity: ringOpacity ?? this.ringOpacity,
    ringBlur: ringBlur ?? this.ringBlur,
    ringWidth: ringWidth ?? this.ringWidth,
    ringOffset: ringOffset ?? this.ringOffset,
  );

  /// Apply a partial override, retaining unspecified fields.
  GlassLensStyle merge(GlassLensStyle? other) => other == null
      ? this
      : GlassLensStyle(
          glass: other.glass ?? glass,
          optics: other.optics ?? optics,
          blur: other.blur ?? blur,
          shape: other.shape ?? shape,
          minifyUnderlay: other.minifyUnderlay ?? minifyUnderlay,
          shadow: other.shadow ?? shadow,
          scaleShadows: other.scaleShadows ?? scaleShadows,
          shadowOpacity: other.shadowOpacity ?? shadowOpacity,
          shadowBlur: other.shadowBlur ?? shadowBlur,
          shadowOffset: other.shadowOffset ?? shadowOffset,
          ringOpacity: other.ringOpacity ?? ringOpacity,
          ringBlur: other.ringBlur ?? ringBlur,
          ringWidth: other.ringWidth ?? ringWidth,
          ringOffset: other.ringOffset ?? ringOffset,
        );
}

/// Reusable button defaults; explicit widget arguments take precedence.
///
/// Unspecified fields inherit the surrounding theme, then native defaults.
@immutable
class GlassButtonAppearance {
  const GlassButtonAppearance({
    this.buttonStyle,
    this.glass,
    this.optics,
    this.blur,
    this.motion,
    this.shape,
    this.padding,
    this.minimumSize,
    this.textStyle,
    this.iconSize,
    this.foregroundColor,
  }) : assert(blur == null || blur >= 0 && blur <= 12),
       assert(iconSize == null || iconSize > 0);
  final GlassButtonStyle? buttonStyle;
  final Glass? glass;

  /// A complete optical packet; supplied values replace the calculated recipe.
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassMotion? motion;
  final GlassShape? shape;
  final EdgeInsetsGeometry? padding;

  /// Minimum button extent; larger content can still expand it.
  final Size? minimumSize;
  final TextStyle? textStyle;
  final double? iconSize;
  final Color? foregroundColor;

  /// Keep existing fields when an argument is null.
  GlassButtonAppearance copyWith({
    GlassButtonStyle? buttonStyle,
    Glass? glass,
    LiquidPrismStyle? optics,
    double? blur,
    GlassMotion? motion,
    GlassShape? shape,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    TextStyle? textStyle,
    double? iconSize,
    Color? foregroundColor,
  }) => GlassButtonAppearance(
    buttonStyle: buttonStyle ?? this.buttonStyle,
    glass: glass ?? this.glass,
    optics: optics ?? this.optics,
    blur: blur ?? this.blur,
    motion: motion ?? this.motion,
    shape: shape ?? this.shape,
    padding: padding ?? this.padding,
    minimumSize: minimumSize ?? this.minimumSize,
    textStyle: textStyle ?? this.textStyle,
    iconSize: iconSize ?? this.iconSize,
    foregroundColor: foregroundColor ?? this.foregroundColor,
  );

  /// Apply a partial override, retaining unspecified fields.
  GlassButtonAppearance merge(GlassButtonAppearance? other) => other == null
      ? this
      : GlassButtonAppearance(
          buttonStyle: other.buttonStyle ?? buttonStyle,
          glass: other.glass ?? glass,
          optics: other.optics ?? optics,
          blur: other.blur ?? blur,
          motion: other.motion ?? motion,
          shape: other.shape ?? shape,
          padding: other.padding ?? padding,
          minimumSize: other.minimumSize ?? minimumSize,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          iconSize: other.iconSize ?? iconSize,
          foregroundColor: other.foregroundColor ?? foregroundColor,
        );
}

/// Switch geometry in logical pixels before [scale] is applied.
///
/// Unspecified fields inherit the surrounding theme, then native defaults.
@immutable
class GlassSwitchStyle {
  const GlassSwitchStyle({
    this.scale,
    this.width,
    this.trackHeight,
    this.hitHeight,
    this.inset,
    this.thumbSize,
    this.liftedThumbSize,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.haptics,
    this.trackShape,
    this.lens,
  }) : assert(scale == null || scale > 0),
       assert(width == null || width > 0),
       assert(trackHeight == null || trackHeight > 0),
       assert(hitHeight == null || hitHeight >= 44),
       assert(inset == null || inset >= 0);

  /// Proportional geometry scale. Touch height remains at least 44 points.
  final double? scale;

  /// Preferred width before scaling; parent constraints still apply.
  final double? width;
  final double? trackHeight;

  /// Minimum touch height before scaling; must be at least 44 points.
  final double? hitHeight;
  final double? inset;

  /// Resting thumb size before scaling.
  final Size? thumbSize;

  /// Fully lifted thumb size before scaling; native switch is 58 × 38⅓.
  final Size? liftedThumbSize;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final bool? haptics;
  final GlassShape? trackShape;

  /// Component-specific overrides of the shared theme lens.
  final GlassLensStyle? lens;

  /// Keep existing fields when an argument is null.
  GlassSwitchStyle copyWith({
    double? scale,
    double? width,
    double? trackHeight,
    double? hitHeight,
    double? inset,
    Size? thumbSize,
    Size? liftedThumbSize,
    Color? activeColor,
    Color? inactiveColor,
    Color? thumbColor,
    bool? haptics,
    GlassShape? trackShape,
    GlassLensStyle? lens,
  }) => GlassSwitchStyle(
    scale: scale ?? this.scale,
    width: width ?? this.width,
    trackHeight: trackHeight ?? this.trackHeight,
    hitHeight: hitHeight ?? this.hitHeight,
    inset: inset ?? this.inset,
    thumbSize: thumbSize ?? this.thumbSize,
    liftedThumbSize: liftedThumbSize ?? this.liftedThumbSize,
    activeColor: activeColor ?? this.activeColor,
    inactiveColor: inactiveColor ?? this.inactiveColor,
    thumbColor: thumbColor ?? this.thumbColor,
    haptics: haptics ?? this.haptics,
    trackShape: trackShape ?? this.trackShape,
    lens: lens ?? this.lens,
  );

  /// Apply a partial override, retaining unspecified fields.
  GlassSwitchStyle merge(GlassSwitchStyle? other) => other == null
      ? this
      : GlassSwitchStyle(
          scale: other.scale ?? scale,
          width: other.width ?? width,
          trackHeight: other.trackHeight ?? trackHeight,
          hitHeight: other.hitHeight ?? hitHeight,
          inset: other.inset ?? inset,
          thumbSize: other.thumbSize ?? thumbSize,
          liftedThumbSize: other.liftedThumbSize ?? liftedThumbSize,
          activeColor: other.activeColor ?? activeColor,
          inactiveColor: other.inactiveColor ?? inactiveColor,
          thumbColor: other.thumbColor ?? thumbColor,
          haptics: other.haptics ?? haptics,
          trackShape: other.trackShape ?? trackShape,
          lens: (lens ?? const GlassLensStyle()).merge(other.lens),
        );
}

/// Slider geometry, colors and thumb treatment. Parent constraints set the final width.
///
/// Unspecified fields inherit the surrounding theme, then native defaults.
@immutable
class GlassSliderStyle {
  const GlassSliderStyle({
    this.width,
    this.scale,
    this.hitHeight,
    this.trackHeight,
    this.thumbSize,
    this.heldScale,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.trackShape,
    this.lens,
  }) : assert(width == null || width > 0),
       assert(scale == null || scale > 0),
       assert(hitHeight == null || hitHeight >= 44),
       assert(trackHeight == null || trackHeight > 0),
       assert(heldScale == null || heldScale >= 1);

  /// Preferred width before scaling; parent constraints still apply.
  final double? width;

  /// Proportional geometry scale. Touch height remains at least 44 points.
  final double? scale;

  /// Minimum touch height before scaling; must be at least 44 points.
  final double? hitHeight;
  final double? trackHeight;

  /// Resting thumb size before scaling.
  final Size? thumbSize;

  /// Thumb enlargement while held. Native slider defaults to 1.55.
  final double? heldScale;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final GlassShape? trackShape;

  /// Component-specific overrides of the shared theme lens.
  final GlassLensStyle? lens;

  /// Keep existing fields when an argument is null.
  GlassSliderStyle copyWith({
    double? width,
    double? scale,
    double? hitHeight,
    double? trackHeight,
    Size? thumbSize,
    double? heldScale,
    Color? activeColor,
    Color? inactiveColor,
    Color? thumbColor,
    GlassShape? trackShape,
    GlassLensStyle? lens,
  }) => GlassSliderStyle(
    width: width ?? this.width,
    scale: scale ?? this.scale,
    hitHeight: hitHeight ?? this.hitHeight,
    trackHeight: trackHeight ?? this.trackHeight,
    thumbSize: thumbSize ?? this.thumbSize,
    heldScale: heldScale ?? this.heldScale,
    activeColor: activeColor ?? this.activeColor,
    inactiveColor: inactiveColor ?? this.inactiveColor,
    thumbColor: thumbColor ?? this.thumbColor,
    trackShape: trackShape ?? this.trackShape,
    lens: lens ?? this.lens,
  );

  /// Apply a partial override, retaining unspecified fields.
  GlassSliderStyle merge(GlassSliderStyle? other) => other == null
      ? this
      : GlassSliderStyle(
          width: other.width ?? width,
          scale: other.scale ?? scale,
          hitHeight: other.hitHeight ?? hitHeight,
          trackHeight: other.trackHeight ?? trackHeight,
          thumbSize: other.thumbSize ?? thumbSize,
          heldScale: other.heldScale ?? heldScale,
          activeColor: other.activeColor ?? activeColor,
          inactiveColor: other.inactiveColor ?? inactiveColor,
          thumbColor: other.thumbColor ?? thumbColor,
          trackShape: other.trackShape ?? trackShape,
          lens: (lens ?? const GlassLensStyle()).merge(other.lens),
        );
}

/// Segmented track, typography and selection geometry.
///
/// Unspecified fields inherit the surrounding theme, then native defaults.
@immutable
class GlassSegmentedStyle {
  const GlassSegmentedStyle({
    this.width,
    this.scale,
    this.hitHeight,
    this.trackHeight,
    this.thumbHeight,
    this.selectionInset,
    this.liftInset,
    this.labelStyle,
    this.backgroundColor,
    this.thumbColor,
    this.foregroundColor,
    this.selectedForegroundColor,
    this.trackShape,
    this.lens,
  }) : assert(width == null || width > 0),
       assert(scale == null || scale > 0),
       assert(hitHeight == null || hitHeight >= 44),
       assert(trackHeight == null || trackHeight > 0),
       assert(thumbHeight == null || thumbHeight > 0),
       assert(selectionInset == null || selectionInset >= 0);

  /// Preferred width before scaling; parent constraints still apply.
  final double? width;

  /// Proportional geometry scale. Touch height remains at least 44 points.
  final double? scale;

  /// Minimum touch height before scaling; must be at least 44 points.
  final double? hitHeight;
  final double? trackHeight;
  final double? thumbHeight;
  final double? selectionInset;

  /// Extra space on each side of the lifted selection (width and height).
  final Size? liftInset;
  final TextStyle? labelStyle;
  final Color? backgroundColor;
  final Color? thumbColor;
  final Color? foregroundColor;
  final Color? selectedForegroundColor;
  final GlassShape? trackShape;

  /// Component-specific overrides of the shared theme lens.
  final GlassLensStyle? lens;

  /// Keep existing fields when an argument is null.
  GlassSegmentedStyle copyWith({
    double? width,
    double? scale,
    double? hitHeight,
    double? trackHeight,
    double? thumbHeight,
    double? selectionInset,
    Size? liftInset,
    TextStyle? labelStyle,
    Color? backgroundColor,
    Color? thumbColor,
    Color? foregroundColor,
    Color? selectedForegroundColor,
    GlassShape? trackShape,
    GlassLensStyle? lens,
  }) => GlassSegmentedStyle(
    width: width ?? this.width,
    scale: scale ?? this.scale,
    hitHeight: hitHeight ?? this.hitHeight,
    trackHeight: trackHeight ?? this.trackHeight,
    thumbHeight: thumbHeight ?? this.thumbHeight,
    selectionInset: selectionInset ?? this.selectionInset,
    liftInset: liftInset ?? this.liftInset,
    labelStyle: labelStyle ?? this.labelStyle,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    thumbColor: thumbColor ?? this.thumbColor,
    foregroundColor: foregroundColor ?? this.foregroundColor,
    selectedForegroundColor:
        selectedForegroundColor ?? this.selectedForegroundColor,
    trackShape: trackShape ?? this.trackShape,
    lens: lens ?? this.lens,
  );

  /// Apply a partial override, retaining unspecified fields.
  GlassSegmentedStyle merge(GlassSegmentedStyle? other) => other == null
      ? this
      : GlassSegmentedStyle(
          width: other.width ?? width,
          scale: other.scale ?? scale,
          hitHeight: other.hitHeight ?? hitHeight,
          trackHeight: other.trackHeight ?? trackHeight,
          thumbHeight: other.thumbHeight ?? thumbHeight,
          selectionInset: other.selectionInset ?? selectionInset,
          liftInset: other.liftInset ?? liftInset,
          labelStyle: labelStyle?.merge(other.labelStyle) ?? other.labelStyle,
          backgroundColor: other.backgroundColor ?? backgroundColor,
          thumbColor: other.thumbColor ?? thumbColor,
          foregroundColor: other.foregroundColor ?? foregroundColor,
          selectedForegroundColor:
              other.selectedForegroundColor ?? selectedForegroundColor,
          trackShape: other.trackShape ?? trackShape,
          lens: (lens ?? const GlassLensStyle()).merge(other.lens),
        );
}

/// Shared toolbar appearance and spacing; item widths remain independently configurable.
///
/// Unspecified fields inherit the surrounding theme, then native defaults.
@immutable
class GlassToolbarStyle {
  const GlassToolbarStyle({
    this.size,
    this.height,
    this.inset,
    this.spacing,
    this.iconSize,
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
  }) : assert(height == null || height >= 44),
       assert(inset == null || inset >= 0),
       assert(spacing == null || spacing >= 0),
       assert(iconSize == null || iconSize > 0),
       assert(blur == null || blur >= 0 && blur <= 12),
       assert(groupSpacing == null || groupSpacing >= 0);
  final GlassToolbarSize? size;
  final double? height;
  final double? inset;
  final double? spacing;
  final double? iconSize;
  final Color? foregroundColor;
  final Color? pressedColor;
  final GlassShape? shape;
  final GlassShape? itemShape;
  final Glass? glass;

  /// A complete optical packet; supplied values replace the calculated recipe.
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassMotion? motion;

  /// How items added to or removed from a group arrive and leave: the capsule
  /// resizes while the item materializes. Defaults to
  /// [GlassTransition.materialize]; [GlassTransition.identity] swaps at once.
  final GlassTransition? itemTransition;

  /// Timing of [itemTransition] and of whole groups appearing in a
  /// [LiquidPrismToolbar]. Defaults to the theme's transition style.
  final GlassTransitionStyle? itemTransitionStyle;

  /// Gap between the capsules of a [LiquidPrismToolbar]. Defaults to 8.
  final double? groupSpacing;

  /// Keep existing fields when an argument is null.
  GlassToolbarStyle copyWith({
    GlassToolbarSize? size,
    double? height,
    double? inset,
    double? spacing,
    double? iconSize,
    Color? foregroundColor,
    Color? pressedColor,
    GlassShape? shape,
    GlassShape? itemShape,
    Glass? glass,
    LiquidPrismStyle? optics,
    double? blur,
    GlassMotion? motion,
    GlassTransition? itemTransition,
    GlassTransitionStyle? itemTransitionStyle,
    double? groupSpacing,
  }) => GlassToolbarStyle(
    size: size ?? this.size,
    height: height ?? this.height,
    inset: inset ?? this.inset,
    spacing: spacing ?? this.spacing,
    iconSize: iconSize ?? this.iconSize,
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
  );

  /// Apply a partial override, retaining unspecified fields.
  GlassToolbarStyle merge(GlassToolbarStyle? other) => other == null
      ? this
      : GlassToolbarStyle(
          size: other.size ?? size,
          height: other.height ?? height,
          inset: other.inset ?? inset,
          spacing: other.spacing ?? spacing,
          iconSize: other.iconSize ?? iconSize,
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
              (itemTransitionStyle ?? const GlassTransitionStyle()).merge(
                other.itemTransitionStyle,
              ),
          groupSpacing: other.groupSpacing ?? groupSpacing,
        );
}

/// Search appearance. Text input behavior stays on the widget.
///
/// Unspecified fields inherit the surrounding theme, then native defaults.
@immutable
class GlassSearchStyle {
  const GlassSearchStyle({
    this.height,
    this.restingInset,
    this.showCancelButton,
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
  }) : assert(height == null || height >= 44),
       assert(restingInset == null || restingInset >= 0),
       assert(iconSize == null || iconSize > 0),
       assert(clearWidth == null || clearWidth > 0),
       assert(cancelWidth == null || cancelWidth >= 44),
       assert(cancelSpacing == null || cancelSpacing >= 0),
       assert(blur == null || blur >= 0 && blur <= 12);
  final double? height;
  final double? restingInset;
  final bool? showCancelButton;
  final bool? showClearButton;
  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;
  final Color? iconColor;
  final Color? cursorColor;
  final Color? clearColor;
  final double? iconSize;

  /// Editor padding between the prefix and suffix. Defaults to zero; the
  /// default search icon carries its own [prefixPadding].
  final EdgeInsetsGeometry? padding;

  /// Padding around the default search icon. Defaults to 12 at the start and
  /// 8 at the end. A custom `prefix` supplies its own spacing.
  final EdgeInsetsGeometry? prefixPadding;
  final double? clearWidth;
  final double? cancelWidth;
  final double? cancelSpacing;
  final GlassShape? shape;
  final Glass? glass;

  /// A complete optical packet; supplied values replace the calculated recipe.
  final LiquidPrismStyle? optics;
  final double? blur;

  /// Field focus spring: the inset dissolves and the field shortens to make
  /// room for cancellation. Also hides the cancel action. Defaults to 380 ms,
  /// zero bounce, matching the native 0.3833 s search transition.
  final GlassSpring? focusSpring;

  /// Spring that slides, scales and fades the cancel action in after focus.
  /// Defaults to 520 ms with 0.22 bounce.
  final GlassSpring? cancelSpring;

  /// Keep existing fields when an argument is null.
  GlassSearchStyle copyWith({
    double? height,
    double? restingInset,
    bool? showCancelButton,
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
    GlassShape? shape,
    Glass? glass,
    LiquidPrismStyle? optics,
    double? blur,
    GlassSpring? focusSpring,
    GlassSpring? cancelSpring,
  }) => GlassSearchStyle(
    height: height ?? this.height,
    restingInset: restingInset ?? this.restingInset,
    showCancelButton: showCancelButton ?? this.showCancelButton,
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

  /// Apply a partial override, retaining unspecified fields.
  GlassSearchStyle merge(GlassSearchStyle? other) => other == null
      ? this
      : GlassSearchStyle(
          height: other.height ?? height,
          restingInset: other.restingInset ?? restingInset,
          showCancelButton: other.showCancelButton ?? showCancelButton,
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
}
