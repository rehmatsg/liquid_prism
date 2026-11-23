import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_optics.dart';

/// Optics and elevation shared by lifted control handles and selection pills.
@immutable
class PrismLensStyle {
  /// Creates a partial lifted-lens style override.
  const new({
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
    this.rimWidth,
    this.rimRefraction,
    this.rimLight,
    this.chromaticAberration,
    this.chromaticBand,
    this.faceBlack,
    this.heldContactShadow,
  }) : assert(
         blur == null || (blur >= 0 && blur <= 12),
         'blur must be between 0 and 12.',
       ),
       assert(
         rimWidth == null || rimWidth >= 0,
         'rimWidth must be non-negative.',
       ),
       assert(
         rimRefraction == null || rimRefraction >= 0,
         'rimRefraction must be non-negative.',
       ),
       assert(
         rimLight == null || rimLight >= 0,
         'rimLight must be non-negative.',
       ),
       assert(
         chromaticAberration == null || chromaticAberration >= 0,
         'chromaticAberration must be non-negative.',
       ),
       assert(
         chromaticBand == null || chromaticBand >= 0,
         'chromaticBand must be non-negative.',
       ),
       assert(
         faceBlack == null || (faceBlack >= 0 && faceBlack <= 1),
         'faceBlack must be between 0 and 1.',
       ),
       assert(
         shadowOpacity == null || (shadowOpacity >= 0 && shadowOpacity <= 1),
         'shadowOpacity must be between 0 and 1.',
       ),
       assert(
         shadowBlur == null || shadowBlur >= 0,
         'shadowBlur must be non-negative.',
       ),
       assert(
         ringOpacity == null || (ringOpacity >= 0 && ringOpacity <= 1),
         'ringOpacity must be between 0 and 1.',
       ),
       assert(
         ringBlur == null || ringBlur >= 0,
         'ringBlur must be non-negative.',
       ),
       assert(
         ringWidth == null || ringWidth >= 0,
         'ringWidth must be non-negative.',
       );

  /// Material recipe for the lifted lens.
  final PrismGlass? glass;

  /// Complete optical override replacing the calculated lens recipe.
  final PrismOptics? optics;

  /// Backdrop frost sigma override in logical pixels.
  final double? blur;

  /// Contour shape of the lens.
  final PrismShape? shape;

  /// Whether content visible beneath the lens minifies while lifted.
  final bool? minifyUnderlay;

  /// Whether resting and lifted exterior shadows are painted.
  final bool? shadow;

  /// Whether shadow metrics scale proportionally with lens height.
  final bool? scaleShadows;

  /// Exterior drop shadow opacity.
  final double? shadowOpacity;

  /// Exterior drop shadow blur sigma.
  final double? shadowBlur;

  /// Exterior drop shadow offset.
  final Offset? shadowOffset;

  /// Outer rim contact ring opacity.
  final double? ringOpacity;

  /// Outer rim contact ring blur sigma.
  final double? ringBlur;

  /// Outer rim contact ring width.
  final double? ringWidth;

  /// Outer rim contact ring offset.
  final Offset? ringOffset;

  /// Refracting rim width scaled from the reference lens height.
  final double? rimWidth;

  /// Rim displacement magnitude at full lift.
  final double? rimRefraction;

  /// Rim lighting highlight strength at full lift.
  final double? rimLight;

  /// Along-rim chromatic split in logical pixels.
  final double? chromaticAberration;

  /// Depth of the chromatic rim band in logical pixels.
  final double? chromaticBand;

  /// Black-point lift applied to the lens face.
  final double? faceBlack;

  /// Whether a contact shadow stays under the lifted lens.
  final bool? heldContactShadow;

  /// Returns a copy with specified fields replaced.
  PrismLensStyle copyWith({
    PrismGlass? glass,
    PrismOptics? optics,
    double? blur,
    PrismShape? shape,
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
    double? rimWidth,
    double? rimRefraction,
    double? rimLight,
    double? chromaticAberration,
    double? chromaticBand,
    double? faceBlack,
    bool? heldContactShadow,
  }) => PrismLensStyle(
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
    rimWidth: rimWidth ?? this.rimWidth,
    rimRefraction: rimRefraction ?? this.rimRefraction,
    rimLight: rimLight ?? this.rimLight,
    chromaticAberration: chromaticAberration ?? this.chromaticAberration,
    chromaticBand: chromaticBand ?? this.chromaticBand,
    faceBlack: faceBlack ?? this.faceBlack,
    heldContactShadow: heldContactShadow ?? this.heldContactShadow,
  );

  /// Merges non-null fields from [other] over this style.
  PrismLensStyle merge(PrismLensStyle? other) => other == null
      ? this
      : PrismLensStyle(
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
          rimWidth: other.rimWidth ?? rimWidth,
          rimRefraction: other.rimRefraction ?? rimRefraction,
          rimLight: other.rimLight ?? rimLight,
          chromaticAberration: other.chromaticAberration ?? chromaticAberration,
          chromaticBand: other.chromaticBand ?? chromaticBand,
          faceBlack: other.faceBlack ?? faceBlack,
          heldContactShadow: other.heldContactShadow ?? heldContactShadow,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismLensStyle &&
          other.glass == glass &&
          other.optics == optics &&
          other.blur == blur &&
          other.shape == shape &&
          other.minifyUnderlay == minifyUnderlay &&
          other.shadow == shadow &&
          other.scaleShadows == scaleShadows &&
          other.shadowOpacity == shadowOpacity &&
          other.shadowBlur == shadowBlur &&
          other.shadowOffset == shadowOffset &&
          other.ringOpacity == ringOpacity &&
          other.ringBlur == ringBlur &&
          other.ringWidth == ringWidth &&
          other.ringOffset == ringOffset &&
          other.rimWidth == rimWidth &&
          other.rimRefraction == rimRefraction &&
          other.rimLight == rimLight &&
          other.chromaticAberration == chromaticAberration &&
          other.chromaticBand == chromaticBand &&
          other.faceBlack == faceBlack &&
          other.heldContactShadow == heldContactShadow;

  @override
  int get hashCode => Object.hashAll([
    glass,
    optics,
    blur,
    shape,
    minifyUnderlay,
    shadow,
    scaleShadows,
    shadowOpacity,
    shadowBlur,
    shadowOffset,
    ringOpacity,
    ringBlur,
    ringWidth,
    ringOffset,
    rimWidth,
    rimRefraction,
    rimLight,
    chromaticAberration,
    chromaticBand,
    faceBlack,
    heldContactShadow,
  ]);
}
