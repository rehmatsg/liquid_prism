import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_lens_style.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';

/// Geometry, colors, and lens overrides for `PrismSwitch`.
@immutable
class PrismSwitchStyle {
  /// Creates a partial switch style override.
  const new({
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
    this.motion,
  }) : assert(scale == null || scale > 0, 'Scale must be positive.'),
       assert(width == null || width > 0, 'Width must be positive.'),
       assert(
         trackHeight == null || trackHeight > 0,
         'Track height must be positive.',
       ),
       assert(
         hitHeight == null || hitHeight >= 44,
         'Hit height must be at least 44.',
       ),
       assert(inset == null || inset >= 0, 'Inset must be non-negative.');

  /// Proportional geometry scale multiplier.
  final double? scale;

  /// Preferred track width before scaling.
  final double? width;

  /// Track height before scaling.
  final double? trackHeight;

  /// Minimum touch target height before scaling.
  final double? hitHeight;

  /// Inset between track and resting thumb before scaling.
  final double? inset;

  /// Resting thumb size before scaling.
  final Size? thumbSize;

  /// Fully lifted thumb size before scaling.
  final Size? liftedThumbSize;

  /// Track fill color when active.
  final Color? activeColor;

  /// Track fill color when inactive.
  final Color? inactiveColor;

  /// Resting thumb fill color.
  final Color? thumbColor;

  /// Whether toggle haptics are enabled.
  final bool? haptics;

  /// Contour shape of the track.
  final PrismShape? trackShape;

  /// Lifted lens overrides.
  final PrismLensStyle? lens;

  /// Spring motion overrides.
  final PrismControlMotion? motion;

  /// Returns a copy with specified fields replaced.
  PrismSwitchStyle copyWith({
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
    PrismShape? trackShape,
    PrismLensStyle? lens,
    PrismControlMotion? motion,
  }) => PrismSwitchStyle(
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
    motion: motion ?? this.motion,
  );

  /// Merges non-null fields from [other] over this style.
  PrismSwitchStyle merge(PrismSwitchStyle? other) => other == null
      ? this
      : PrismSwitchStyle(
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
          lens: lens == null && other.lens == null
              ? null
              : (lens ?? const PrismLensStyle()).merge(other.lens),
          motion: motion == null && other.motion == null
              ? null
              : (motion ?? const PrismControlMotion()).merge(other.motion),
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismSwitchStyle &&
          other.scale == scale &&
          other.width == width &&
          other.trackHeight == trackHeight &&
          other.hitHeight == hitHeight &&
          other.inset == inset &&
          other.thumbSize == thumbSize &&
          other.liftedThumbSize == liftedThumbSize &&
          other.activeColor == activeColor &&
          other.inactiveColor == inactiveColor &&
          other.thumbColor == thumbColor &&
          other.haptics == haptics &&
          other.trackShape == trackShape &&
          other.lens == lens &&
          other.motion == motion;

  @override
  int get hashCode => Object.hash(
    scale,
    width,
    trackHeight,
    hitHeight,
    inset,
    thumbSize,
    liftedThumbSize,
    activeColor,
    inactiveColor,
    thumbColor,
    haptics,
    trackShape,
    lens,
    motion,
  );
}
