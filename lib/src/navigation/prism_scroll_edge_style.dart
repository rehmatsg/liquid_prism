import 'package:flutter/widgets.dart';

import '../core/prism_motion.dart';
import '../theme/prism_theme.dart';

/// How a scroll edge effect terminates at a bar's inner boundary.
enum PrismScrollEdgeVariant { soft, hard }

/// Appearance and timing overrides for [PrismScrollEdge].
@immutable
class PrismScrollEdgeStyle {
  /// Creates a partial scroll edge style override.
  const PrismScrollEdgeStyle({
    this.variant,
    this.sigma,
    this.falloff,
    this.extension,
    this.floor,
    this.fadeColor,
    this.fadeOpacity,
    this.haze,
    this.hazeOpacity,
    this.hairline,
    this.revealExtent,
    this.spring,
  }) : assert(sigma == null || sigma >= 0),
       assert(falloff == null || falloff >= 0),
       assert(extension == null || extension >= 0),
       assert(floor == null || (floor >= 0 && floor <= 1)),
       assert(fadeOpacity == null || (fadeOpacity >= 0 && fadeOpacity <= 1)),
       assert(haze == null || haze >= 0),
       assert(hazeOpacity == null || (hazeOpacity >= 0 && hazeOpacity <= 1)),
       assert(revealExtent == null || revealExtent > 0);

  /// Soft or hard edge termination.
  final PrismScrollEdgeVariant? variant;

  /// Full-strength Gaussian blur sigma in logical pixels.
  final double? sigma;

  /// Falloff depth from the effect's inner end in logical pixels.
  final double? falloff;

  /// Soft reach past the bar box in logical pixels.
  final double? extension;

  /// Fraction of full strength retained at the inner boundary.
  final double? floor;

  /// Surface color content fades toward.
  final Color? fadeColor;

  /// Maximum fade opacity at the outer edge.
  final double? fadeOpacity;

  /// Heavy haze blur sigma blended into the strip.
  final double? haze;

  /// Opacity of the heavy haze layer.
  final double? hazeOpacity;

  /// Whether the hard variant draws a 1-device-pixel hairline.
  final bool? hairline;

  /// Scroll distance over which the effect fades in.
  final double? revealExtent;

  /// Spring animating scroll-fade presence changes.
  final PrismSpring? spring;

  /// Default soft blur sigma.
  static const double defaultSigma = 3;

  /// Default soft falloff distance.
  static const double defaultFalloff = 98;

  /// Default soft reach past the bar box.
  static const double defaultExtension = 50;

  /// Default top fade opacity.
  static const double defaultFadeOpacity = .5;

  /// Default bottom fade opacity.
  static const double defaultBottomFadeOpacity = .45;

  /// Default heavy haze blur sigma.
  static const double defaultHaze = 32;

  /// Default haze opacity.
  static const double defaultHazeOpacity = .5;

  /// Default haze plateau fraction.
  static const double defaultHazePlateau = .34;

  /// Default scroll distance to full reveal.
  static const double defaultRevealExtent = 16;

  /// Default hard blur sigma.
  static const double defaultHardSigma = 4;

  /// Default hard falloff distance.
  static const double defaultHardFalloff = 51;

  /// Default hard inner floor fraction.
  static const double defaultHardFloor = .25;

  /// Light appearance hairline color.
  static const Color hairlineColor = Color(0x1A000000);

  /// Dark appearance hairline color.
  static const Color darkHairlineColor = Color(0x1AFFFFFF);

  /// Returns the hairline color for [brightness].
  static Color hairlineColorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkHairlineColor : hairlineColor;

  /// Resolves the theme style merged with [override].
  static PrismScrollEdgeStyle resolve(
    BuildContext context,
    PrismScrollEdgeStyle? override,
  ) => (PrismTheme.of(context).scrollEdge ?? const PrismScrollEdgeStyle())
      .merge(override);

  /// Returns a copy with specified fields replaced.
  PrismScrollEdgeStyle copyWith({
    PrismScrollEdgeVariant? variant,
    double? sigma,
    double? falloff,
    double? extension,
    double? floor,
    Color? fadeColor,
    double? fadeOpacity,
    double? haze,
    double? hazeOpacity,
    bool? hairline,
    double? revealExtent,
    PrismSpring? spring,
  }) => PrismScrollEdgeStyle(
    variant: variant ?? this.variant,
    sigma: sigma ?? this.sigma,
    falloff: falloff ?? this.falloff,
    extension: extension ?? this.extension,
    floor: floor ?? this.floor,
    fadeColor: fadeColor ?? this.fadeColor,
    fadeOpacity: fadeOpacity ?? this.fadeOpacity,
    haze: haze ?? this.haze,
    hazeOpacity: hazeOpacity ?? this.hazeOpacity,
    hairline: hairline ?? this.hairline,
    revealExtent: revealExtent ?? this.revealExtent,
    spring: spring ?? this.spring,
  );

  /// Merges non-null fields from [other] over this style.
  PrismScrollEdgeStyle merge(PrismScrollEdgeStyle? other) => other == null
      ? this
      : PrismScrollEdgeStyle(
          variant: other.variant ?? variant,
          sigma: other.sigma ?? sigma,
          falloff: other.falloff ?? falloff,
          extension: other.extension ?? extension,
          floor: other.floor ?? floor,
          fadeColor: other.fadeColor ?? fadeColor,
          fadeOpacity: other.fadeOpacity ?? fadeOpacity,
          haze: other.haze ?? haze,
          hazeOpacity: other.hazeOpacity ?? hazeOpacity,
          hairline: other.hairline ?? hairline,
          revealExtent: other.revealExtent ?? revealExtent,
          spring: other.spring ?? spring,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismScrollEdgeStyle &&
          other.variant == variant &&
          other.sigma == sigma &&
          other.falloff == falloff &&
          other.extension == extension &&
          other.floor == floor &&
          other.fadeColor == fadeColor &&
          other.fadeOpacity == fadeOpacity &&
          other.haze == haze &&
          other.hazeOpacity == hazeOpacity &&
          other.hairline == hairline &&
          other.revealExtent == revealExtent &&
          other.spring == spring;

  @override
  int get hashCode => Object.hash(
    variant,
    sigma,
    falloff,
    extension,
    floor,
    fadeColor,
    fadeOpacity,
    haze,
    hazeOpacity,
    hairline,
    revealExtent,
    spring,
  );
}
