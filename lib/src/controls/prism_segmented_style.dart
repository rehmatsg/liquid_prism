import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_lens_style.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';

/// Sizing behavior for `PrismSegmentedControl`.
enum PrismSegmentedSizing {
  /// Uses the preferred width for equal segment slots.
  fixed,

  /// Sizes equal segment slots to fit the widest label.
  fitLabels,
}

/// Track, typography, and selection overrides for `PrismSegmentedControl`.
@immutable
class PrismSegmentedStyle {
  /// Creates a partial segmented control style override.
  const new({
    this.width,
    this.sizing,
    this.labelPadding,
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
    this.refractContent,
    this.contentRefraction,
    this.contentDepth,
    this.motion,
  }) : assert(width == null || width > 0, 'Width must be positive.'),
       assert(scale == null || scale > 0, 'Scale must be positive.'),
       assert(
         hitHeight == null || hitHeight >= 44,
         'Hit height must be at least 44.',
       ),
       assert(
         trackHeight == null || trackHeight > 0,
         'Track height must be positive.',
       ),
       assert(
         thumbHeight == null || thumbHeight > 0,
         'Thumb height must be positive.',
       ),
       assert(
         selectionInset == null || selectionInset >= 0,
         'Selection inset must be non-negative.',
       ),
       assert(
         contentRefraction == null ||
             (contentRefraction >= 0 && contentRefraction <= 64),
         'Content refraction must be between 0 and 64.',
       ),
       assert(
         contentDepth == null || contentDepth > 0,
         'Content depth must be positive.',
       );

  /// Preferred width before scaling.
  final double? width;

  /// Horizontal sizing strategy.
  final PrismSegmentedSizing? sizing;

  /// Padding around labels when [sizing] is [PrismSegmentedSizing.fitLabels].
  final EdgeInsetsGeometry? labelPadding;

  /// Proportional geometry scale multiplier.
  final double? scale;

  /// Minimum touch target height before scaling.
  final double? hitHeight;

  /// Track height before scaling.
  final double? trackHeight;

  /// Resting selection thumb height before scaling.
  final double? thumbHeight;

  /// Inset between track and resting selection.
  final double? selectionInset;

  /// Extra expansion around the lifted selection lens.
  final Size? liftInset;

  /// Label text style override.
  final TextStyle? labelStyle;

  /// Track background fill color.
  final Color? backgroundColor;

  /// Resting selection fill color.
  final Color? thumbColor;

  /// Unselected label foreground color.
  final Color? foregroundColor;

  /// Selected label foreground color.
  final Color? selectedForegroundColor;

  /// Contour shape of the track.
  final PrismShape? trackShape;

  /// Lifted lens overrides.
  final PrismLensStyle? lens;

  /// Whether labels refract near the held selection rim.
  final bool? refractContent;

  /// Foreground refraction displacement magnitude.
  final double? contentRefraction;

  /// Foreground refraction rim depth.
  final double? contentDepth;

  /// Spring motion overrides.
  final PrismControlMotion? motion;

  /// Returns a copy with specified fields replaced.
  PrismSegmentedStyle copyWith({
    double? width,
    PrismSegmentedSizing? sizing,
    EdgeInsetsGeometry? labelPadding,
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
    PrismShape? trackShape,
    PrismLensStyle? lens,
    bool? refractContent,
    double? contentRefraction,
    double? contentDepth,
    PrismControlMotion? motion,
  }) => PrismSegmentedStyle(
    width: width ?? this.width,
    sizing: sizing ?? this.sizing,
    labelPadding: labelPadding ?? this.labelPadding,
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
    refractContent: refractContent ?? this.refractContent,
    contentRefraction: contentRefraction ?? this.contentRefraction,
    contentDepth: contentDepth ?? this.contentDepth,
    motion: motion ?? this.motion,
  );

  /// Merges non-null fields from [other] over this style.
  PrismSegmentedStyle merge(PrismSegmentedStyle? other) => other == null
      ? this
      : PrismSegmentedStyle(
          width: other.width ?? width,
          sizing: other.sizing ?? sizing,
          labelPadding: other.labelPadding ?? labelPadding,
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
          lens: lens == null && other.lens == null
              ? null
              : (lens ?? const PrismLensStyle()).merge(other.lens),
          refractContent: other.refractContent ?? refractContent,
          contentRefraction: other.contentRefraction ?? contentRefraction,
          contentDepth: other.contentDepth ?? contentDepth,
          motion: motion == null && other.motion == null
              ? null
              : (motion ?? const PrismControlMotion()).merge(other.motion),
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismSegmentedStyle &&
          other.width == width &&
          other.sizing == sizing &&
          other.labelPadding == labelPadding &&
          other.scale == scale &&
          other.hitHeight == hitHeight &&
          other.trackHeight == trackHeight &&
          other.thumbHeight == thumbHeight &&
          other.selectionInset == selectionInset &&
          other.liftInset == liftInset &&
          other.labelStyle == labelStyle &&
          other.backgroundColor == backgroundColor &&
          other.thumbColor == thumbColor &&
          other.foregroundColor == foregroundColor &&
          other.selectedForegroundColor == selectedForegroundColor &&
          other.trackShape == trackShape &&
          other.lens == lens &&
          other.refractContent == refractContent &&
          other.contentRefraction == contentRefraction &&
          other.contentDepth == contentDepth &&
          other.motion == motion;

  @override
  int get hashCode => Object.hashAll([
    width,
    sizing,
    labelPadding,
    scale,
    hitHeight,
    trackHeight,
    thumbHeight,
    selectionInset,
    liftInset,
    labelStyle,
    backgroundColor,
    thumbColor,
    foregroundColor,
    selectedForegroundColor,
    trackShape,
    lens,
    refractContent,
    contentRefraction,
    contentDepth,
    motion,
  ]);
}
