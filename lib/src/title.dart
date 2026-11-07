import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'button.dart';
import 'glass.dart';
import 'material.dart';
import 'theme.dart';

/// Geometry of a [LiquidPrismTitle]. Null fields fall back to the theme's
/// `GlassNavigationBarStyle.titleCapsule`, then to the defaults, measured on
/// iOS 27 device screenshots of SwiftUI apps on iPhone Duo (3x, about a third
/// of a point): a 64-point avatar that the capsule tucks 6 points under, a
/// capsule at least 38 points tall with 14 x 9 points of padding (44.3 points
/// with a 26-point inline leading, 10 points before the title).
@immutable
final class GlassTitleStyle {
  const GlassTitleStyle({
    this.avatarSize,
    this.avatarOverlap,
    this.leadingSize,
    this.leadingGap,
    this.padding,
    this.minHeight,
    this.glass,
  }) : assert(avatarSize == null || avatarSize >= 0),
       assert(avatarOverlap == null || avatarOverlap >= 0),
       assert(leadingSize == null || leadingSize >= 0),
       assert(leadingGap == null || leadingGap >= 0),
       assert(minHeight == null || minHeight >= 0);

  /// Side of the square the [LiquidPrismTitle.avatar] is laid out in.
  final double? avatarSize;

  /// How far the capsule's top tucks under the avatar.
  final double? avatarOverlap;

  /// Side of the square the [LiquidPrismTitle.leading] is laid out in.
  final double? leadingSize;

  /// Space between the leading widget and the title.
  final double? leadingGap;

  /// Padding inside the capsule.
  final EdgeInsets? padding;

  /// The capsule's minimum height.
  final double? minHeight;

  /// The capsule's glass; defaults to [Glass.regular].
  final Glass? glass;

  static const _avatarSize = 64.0, _avatarOverlap = 6.0;
  static const _leadingSize = 26.0, _leadingGap = 10.0, _minHeight = 38.0;
  static const _padding = EdgeInsets.symmetric(horizontal: 14, vertical: 9);

  double get resolvedAvatarSize => avatarSize ?? _avatarSize;
  double get resolvedAvatarOverlap => avatarOverlap ?? _avatarOverlap;
  double get resolvedLeadingSize => leadingSize ?? _leadingSize;
  double get resolvedLeadingGap => leadingGap ?? _leadingGap;
  EdgeInsets get resolvedPadding => padding ?? _padding;
  double get resolvedMinHeight => minHeight ?? _minHeight;

  GlassTitleStyle copyWith({
    double? avatarSize,
    double? avatarOverlap,
    double? leadingSize,
    double? leadingGap,
    EdgeInsets? padding,
    double? minHeight,
    Glass? glass,
  }) => GlassTitleStyle(
    avatarSize: avatarSize ?? this.avatarSize,
    avatarOverlap: avatarOverlap ?? this.avatarOverlap,
    leadingSize: leadingSize ?? this.leadingSize,
    leadingGap: leadingGap ?? this.leadingGap,
    padding: padding ?? this.padding,
    minHeight: minHeight ?? this.minHeight,
    glass: glass ?? this.glass,
  );

  /// Fields set on [other] win; explicit zero is kept.
  GlassTitleStyle merge(GlassTitleStyle? other) => other == null
      ? this
      : GlassTitleStyle(
          avatarSize: other.avatarSize ?? avatarSize,
          avatarOverlap: other.avatarOverlap ?? avatarOverlap,
          leadingSize: other.leadingSize ?? leadingSize,
          leadingGap: other.leadingGap ?? leadingGap,
          padding: other.padding ?? padding,
          minHeight: other.minHeight ?? minHeight,
          glass: other.glass ?? glass,
        );

  @override
  bool operator ==(Object other) =>
      other is GlassTitleStyle &&
      other.avatarSize == avatarSize &&
      other.avatarOverlap == avatarOverlap &&
      other.leadingSize == leadingSize &&
      other.leadingGap == leadingGap &&
      other.padding == padding &&
      other.minHeight == minHeight &&
      other.glass == glass;

  @override
  int get hashCode => Object.hash(
    avatarSize,
    avatarOverlap,
    leadingSize,
    leadingGap,
    padding,
    minHeight,
    glass,
  );
}

/// A navigation title in a glass capsule, as SwiftUI apps show a person or a
/// space: [child] (usually a [Text], or any widget) with an optional [leading]
/// inside the capsule before it, such as a small avatar, and an optional
/// [avatar] above it that the capsule tucks under, as in a conversation
/// header. Pass it as [LiquidPrismScaffold.title]; with an [avatar] the bar
/// grows to hold it while the leading control and actions keep their row.
///
/// With [onPressed] the whole capsule is one button with glass press feedback
/// (open a contact card, say); without it the capsule is static. The avatar
/// and leading widgets are laid out in squares of the style's sizes, so the
/// bar's height is known before layout.
class LiquidPrismTitle extends StatelessWidget {
  const LiquidPrismTitle({
    super.key,
    required this.child,
    this.leading,
    this.avatar,
    this.onPressed,
    this.semanticLabel,
    this.style,
  });

  /// The title, styled by the bar's title text style.
  final Widget child;

  /// Inside the capsule, before [child]; laid out in a
  /// [GlassTitleStyle.leadingSize] square.
  final Widget? leading;

  /// Above the capsule, which tucks under it; laid out in a
  /// [GlassTitleStyle.avatarSize] square. Omit it for a capsule alone.
  final Widget? avatar;

  /// Makes the capsule a button.
  final VoidCallback? onPressed;

  /// The button's accessible name when [onPressed] is set; defaults to the
  /// title's own text.
  final String? semanticLabel;
  final GlassTitleStyle? style;

  /// The theme's title style with [style] over it.
  GlassTitleStyle resolve(BuildContext context) =>
      (LiquidPrismTheme.of(context).navigationBar?.titleCapsule ??
              const GlassTitleStyle())
          .merge(style);

  /// The height this title takes in a bar whose title line is [lineHeight]
  /// points tall: the capsule, and the avatar above it.
  static double extentOf(
    LiquidPrismTitle title,
    GlassTitleStyle style,
    double lineHeight,
  ) {
    return _capsuleHeight(title, style, lineHeight) +
        (title.avatar == null
            ? 0
            : math.max(
                0,
                style.resolvedAvatarSize - style.resolvedAvatarOverlap,
              ));
  }

  /// The capsule's height for a title line of [lineHeight] points.
  static double _capsuleHeight(
    LiquidPrismTitle title,
    GlassTitleStyle style,
    double lineHeight,
  ) => math.max(
    style.resolvedMinHeight,
    math.max(
          lineHeight,
          title.leading == null ? 0.0 : style.resolvedLeadingSize,
        ) +
        style.resolvedPadding.vertical,
  );

  @override
  Widget build(BuildContext context) {
    final resolved = resolve(context);
    final padding = resolved.resolvedPadding;
    final leading = this.leading;
    // The line is measured as the scaffold measures it, so the capsule is
    // exactly the height the bar reserved for it.
    final text = DefaultTextStyle.of(context).style;
    final line =
        MediaQuery.textScalerOf(context).scale(text.fontSize ?? 17) *
        (text.height ?? 1.2);
    final content = SizedBox(
      height: math.max(
        0,
        _capsuleHeight(this, resolved, line) - padding.vertical,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            SizedBox.square(
              dimension: resolved.resolvedLeadingSize,
              child: leading,
            ),
            SizedBox(width: resolved.resolvedLeadingGap),
          ],
          Flexible(child: child),
        ],
      ),
    );
    final glass = resolved.glass ?? Glass.regular;
    final Widget capsule = onPressed == null
        ? LiquidPrism(
            glass: glass,
            shape: GlassShape.capsule,
            child: Padding(padding: padding, child: content),
          )
        : LiquidPrismButton(
            onPressed: onPressed,
            label:
                semanticLabel ??
                switch (child) {
                  Text(:final data?) => data,
                  _ => '',
                },
            glass: glass.interactive(),
            shape: GlassShape.capsule,
            padding: padding,
            // A title keeps the bar's title colour, not a button's tint.
            foregroundColor:
                DefaultTextStyle.of(context).style.color ??
                GlassColors.of(context).label,
            child: content,
          );
    final avatar = this.avatar;
    if (avatar == null) return GlassGroupMembers(child: capsule);
    final size = resolved.resolvedAvatarSize;
    final overlap = math.min(resolved.resolvedAvatarOverlap, size);
    // The avatar paints over the capsule's top, as measured.
    return GlassGroupMembers(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: size - overlap),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              capsule,
              Positioned(
                top: overlap - size,
                child: SizedBox.square(dimension: size, child: avatar),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
