import 'package:flutter/widgets.dart';

import '../core/prism_glass.dart';
import '../core/prism_lens_style.dart';
import '../core/prism_motion.dart';

/// Geometry, colors, and thumb overrides for [PrismSlider].
@immutable
class PrismSliderStyle {
  /// Creates a partial slider style override.
  const PrismSliderStyle({
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
    this.haptics,
    this.motion,
  }) : assert(width == null || width > 0),
       assert(scale == null || scale > 0),
       assert(hitHeight == null || hitHeight >= 44),
       assert(trackHeight == null || trackHeight > 0),
       assert(heldScale == null || heldScale >= 1);

  /// Preferred width before scaling.
  final double? width;

  /// Proportional geometry scale multiplier.
  final double? scale;

  /// Minimum touch target height before scaling.
  final double? hitHeight;

  /// Track thickness before scaling.
  final double? trackHeight;

  /// Resting thumb size before scaling.
  final Size? thumbSize;

  /// Thumb enlargement factor while held.
  final double? heldScale;

  /// Active track fill color.
  final Color? activeColor;

  /// Inactive track fill color.
  final Color? inactiveColor;

  /// Resting thumb fill color.
  final Color? thumbColor;

  /// Contour shape of the track.
  final PrismShape? trackShape;

  /// Lifted lens overrides.
  final PrismLensStyle? lens;

  /// Whether limit-reached haptics are enabled.
  final bool? haptics;

  /// Spring motion overrides.
  final PrismControlMotion? motion;

  /// Returns a copy with specified fields replaced.
  PrismSliderStyle copyWith({
    double? width,
    double? scale,
    double? hitHeight,
    double? trackHeight,
    Size? thumbSize,
    double? heldScale,
    Color? activeColor,
    Color? inactiveColor,
    Color? thumbColor,
    PrismShape? trackShape,
    PrismLensStyle? lens,
    bool? haptics,
    PrismControlMotion? motion,
  }) => PrismSliderStyle(
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
    haptics: haptics ?? this.haptics,
    motion: motion ?? this.motion,
  );

  /// Merges non-null fields from [other] over this style.
  PrismSliderStyle merge(PrismSliderStyle? other) => other == null
      ? this
      : PrismSliderStyle(
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
          lens: lens == null && other.lens == null
              ? null
              : (lens ?? const PrismLensStyle()).merge(other.lens),
          haptics: other.haptics ?? haptics,
          motion: motion == null && other.motion == null
              ? null
              : (motion ?? const PrismControlMotion()).merge(other.motion),
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismSliderStyle &&
          other.width == width &&
          other.scale == scale &&
          other.hitHeight == hitHeight &&
          other.trackHeight == trackHeight &&
          other.thumbSize == thumbSize &&
          other.heldScale == heldScale &&
          other.activeColor == activeColor &&
          other.inactiveColor == inactiveColor &&
          other.thumbColor == thumbColor &&
          other.trackShape == trackShape &&
          other.lens == lens &&
          other.haptics == haptics &&
          other.motion == motion;

  @override
  int get hashCode => Object.hash(
    width,
    scale,
    hitHeight,
    trackHeight,
    thumbSize,
    heldScale,
    activeColor,
    inactiveColor,
    thumbColor,
    trackShape,
    lens,
    haptics,
    motion,
  );
}
