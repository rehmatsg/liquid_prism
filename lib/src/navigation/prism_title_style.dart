import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_glass.dart';

/// Geometry and glass overrides for `PrismTitle`.
@immutable
final class PrismTitleStyle {
  /// Creates a partial title capsule style override.
  const new({
    this.avatarSize,
    this.avatarOverlap,
    this.leadingSize,
    this.leadingCornerRadius,
    this.leadingPadding,
    this.padding,
    this.minHeight,
    this.glass,
  }) : assert(
         avatarSize == null || avatarSize >= 0,
         'avatarSize must be >= 0.',
       ),
       assert(
         avatarOverlap == null || avatarOverlap >= 0,
         'avatarOverlap must be >= 0.',
       ),
       assert(
         leadingSize == null || leadingSize >= 0,
         'leadingSize must be >= 0.',
       ),
       assert(
         leadingCornerRadius == null || leadingCornerRadius >= 0,
         'leadingCornerRadius must be >= 0.',
       ),
       assert(minHeight == null || minHeight >= 0, 'minHeight must be >= 0.');

  /// Side length of the square avatar slot.
  final double? avatarSize;

  /// Vertical overlap between the avatar and capsule top.
  final double? avatarOverlap;

  /// Side length of the square inline leading slot.
  final double? leadingSize;

  /// Corner radius of the inline leading shape.
  final double? leadingCornerRadius;

  /// Padding surrounding the inline leading slot.
  final EdgeInsetsDirectional? leadingPadding;

  /// Padding surrounding the title text inside the capsule.
  final EdgeInsets? padding;

  /// Minimum capsule height in logical pixels.
  final double? minHeight;

  /// Surface glass recipe for the capsule.
  final PrismGlass? glass;

  static const double _avatarSize = 64;
  static const double _avatarOverlap = 6;
  static const double _leadingSize = 22;
  static const double _minHeight = 38;
  static const EdgeInsetsDirectional _leadingPadding =
      EdgeInsetsDirectional.fromSTEB(11, 11, 10, 11);
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 9,
  );

  /// Effective avatar slot size.
  double get resolvedAvatarSize => avatarSize ?? _avatarSize;

  /// Effective avatar overlap distance.
  double get resolvedAvatarOverlap => avatarOverlap ?? _avatarOverlap;

  /// Effective inline leading slot size.
  double get resolvedLeadingSize => leadingSize ?? _leadingSize;

  /// Effective corner radius, capped to half [resolvedLeadingSize].
  double get resolvedLeadingCornerRadius {
    final half = resolvedLeadingSize / 2;
    return math.min(leadingCornerRadius ?? half, half);
  }

  /// Effective padding around the inline leading slot.
  EdgeInsetsDirectional get resolvedLeadingPadding =>
      leadingPadding ?? _leadingPadding;

  /// Effective padding around the title text.
  EdgeInsets get resolvedPadding => padding ?? _padding;

  /// Effective minimum capsule height.
  double get resolvedMinHeight => minHeight ?? _minHeight;

  /// Returns a copy with specified fields replaced.
  PrismTitleStyle copyWith({
    double? avatarSize,
    double? avatarOverlap,
    double? leadingSize,
    double? leadingCornerRadius,
    EdgeInsetsDirectional? leadingPadding,
    EdgeInsets? padding,
    double? minHeight,
    PrismGlass? glass,
  }) => PrismTitleStyle(
    avatarSize: avatarSize ?? this.avatarSize,
    avatarOverlap: avatarOverlap ?? this.avatarOverlap,
    leadingSize: leadingSize ?? this.leadingSize,
    leadingCornerRadius: leadingCornerRadius ?? this.leadingCornerRadius,
    leadingPadding: leadingPadding ?? this.leadingPadding,
    padding: padding ?? this.padding,
    minHeight: minHeight ?? this.minHeight,
    glass: glass ?? this.glass,
  );

  /// Merges non-null fields from [other] over this style.
  PrismTitleStyle merge(PrismTitleStyle? other) => other == null
      ? this
      : PrismTitleStyle(
          avatarSize: other.avatarSize ?? avatarSize,
          avatarOverlap: other.avatarOverlap ?? avatarOverlap,
          leadingSize: other.leadingSize ?? leadingSize,
          leadingCornerRadius: other.leadingCornerRadius ?? leadingCornerRadius,
          leadingPadding: other.leadingPadding ?? leadingPadding,
          padding: other.padding ?? padding,
          minHeight: other.minHeight ?? minHeight,
          glass: other.glass ?? glass,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismTitleStyle &&
          other.avatarSize == avatarSize &&
          other.avatarOverlap == avatarOverlap &&
          other.leadingSize == leadingSize &&
          other.leadingCornerRadius == leadingCornerRadius &&
          other.leadingPadding == leadingPadding &&
          other.padding == padding &&
          other.minHeight == minHeight &&
          other.glass == glass;

  @override
  int get hashCode => Object.hash(
    avatarSize,
    avatarOverlap,
    leadingSize,
    leadingCornerRadius,
    leadingPadding,
    padding,
    minHeight,
    glass,
  );
}
