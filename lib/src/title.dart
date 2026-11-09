import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'motion.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'glass.dart';
import 'material.dart';
import 'theme.dart';

const titleCompositionSpring = GlassSpring(
  response: Duration(milliseconds: 450),
  bounce: .3,
);

/// Geometry of a [LiquidPrismTitle]. Null fields fall back to the theme's
/// `GlassNavigationBarStyle.titleCapsule`, then to the defaults, measured on
/// iOS 27 device screenshots of SwiftUI apps on iPhone Duo (3x, about a third
/// of a point): a 64-point avatar that the capsule tucks 6 points under; a
/// capsule at least 38 points tall with 14 x 9 points of padding around the
/// title; and a 22-point inline leading inset 12 points from the capsule's
/// start and 11 above and below, 10 points before the title, which makes the
/// capsule 44 points tall.
@immutable
final class GlassTitleStyle {
  const GlassTitleStyle({
    this.avatarSize,
    this.avatarOverlap,
    this.leadingSize,
    this.leadingPadding,
    this.padding,
    this.minHeight,
    this.glass,
  }) : assert(avatarSize == null || avatarSize >= 0),
       assert(avatarOverlap == null || avatarOverlap >= 0),
       assert(leadingSize == null || leadingSize >= 0),
       assert(minHeight == null || minHeight >= 0);

  /// Side of the square the [LiquidPrismTitle.avatar] is laid out in.
  final double? avatarSize;

  /// How far the capsule's top tucks under the avatar.
  final double? avatarOverlap;

  /// Side of the square the [LiquidPrismTitle.leading] is laid out in.
  final double? leadingSize;

  /// Space around the leading widget: from the capsule's start, top and
  /// bottom, and before the title (end). With a leading widget its start
  /// replaces [padding]'s on that side.
  final EdgeInsetsDirectional? leadingPadding;

  /// Padding around the title inside the capsule.
  final EdgeInsets? padding;

  /// The capsule's minimum height.
  final double? minHeight;

  /// The capsule's glass; defaults to [Glass.regular].
  final Glass? glass;

  static const _avatarSize = 64.0, _avatarOverlap = 6.0;
  static const _leadingSize = 22.0, _minHeight = 38.0;
  static const _leadingPadding = EdgeInsetsDirectional.fromSTEB(12, 11, 10, 11);
  static const _padding = EdgeInsets.symmetric(horizontal: 14, vertical: 9);

  double get resolvedAvatarSize => avatarSize ?? _avatarSize;
  double get resolvedAvatarOverlap => avatarOverlap ?? _avatarOverlap;
  double get resolvedLeadingSize => leadingSize ?? _leadingSize;
  EdgeInsetsDirectional get resolvedLeadingPadding =>
      leadingPadding ?? _leadingPadding;
  EdgeInsets get resolvedPadding => padding ?? _padding;
  double get resolvedMinHeight => minHeight ?? _minHeight;

  GlassTitleStyle copyWith({
    double? avatarSize,
    double? avatarOverlap,
    double? leadingSize,
    EdgeInsetsDirectional? leadingPadding,
    EdgeInsets? padding,
    double? minHeight,
    Glass? glass,
  }) => GlassTitleStyle(
    avatarSize: avatarSize ?? this.avatarSize,
    avatarOverlap: avatarOverlap ?? this.avatarOverlap,
    leadingSize: leadingSize ?? this.leadingSize,
    leadingPadding: leadingPadding ?? this.leadingPadding,
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
          leadingPadding: other.leadingPadding ?? leadingPadding,
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
      other.leadingPadding == leadingPadding &&
      other.padding == padding &&
      other.minHeight == minHeight &&
      other.glass == glass;

  @override
  int get hashCode => Object.hash(
    avatarSize,
    avatarOverlap,
    leadingSize,
    leadingPadding,
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
class LiquidPrismTitle extends StatefulWidget {
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
    math.max(
      style.resolvedMinHeight,
      lineHeight + style.resolvedPadding.vertical,
    ),
    title.leading == null
        ? 0.0
        : style.resolvedLeadingSize + style.resolvedLeadingPadding.vertical,
  );

  @override
  State<LiquidPrismTitle> createState() => _LiquidPrismTitleState();
}

class _LiquidPrismTitleState extends State<LiquidPrismTitle>
    with TickerProviderStateMixin {
  late final _above = RetargetableGlassSpring(vsync: this)
    ..value = widget.avatar == null ? 0 : 1;
  late final _inline = RetargetableGlassSpring(vsync: this)
    ..value = widget.leading == null ? 0 : 1;
  late final _placement = RetargetableGlassSpring(vsync: this)
    ..value = widget.avatar == null ? 1 : 0;
  Widget? _avatar;
  bool _immediate = false;

  void _sync() {
    _avatar = widget.avatar ?? widget.leading ?? _avatar;
    if (widget.avatar != null || widget.leading != null) {
      springGlass(
        _placement,
        widget.avatar == null ? 1 : 0,
        titleCompositionSpring.description,
        immediate: _immediate,
      );
    }
    springGlass(
      _above,
      widget.avatar == null ? 0 : 1,
      titleCompositionSpring.description,
      immediate: _immediate,
    );
    springGlass(
      _inline,
      widget.leading == null ? 0 : 1,
      titleCompositionSpring.description,
      immediate: _immediate,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _avatar ??= widget.avatar ?? widget.leading;
    final immediate = MediaQuery.disableAnimationsOf(context);
    if (_immediate != immediate) {
      _immediate = immediate;
      _sync();
    }
  }

  @override
  void didUpdateWidget(LiquidPrismTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.avatar == null) != (widget.avatar == null) ||
        (oldWidget.leading == null) != (widget.leading == null)) {
      _sync();
    }
    _avatar = widget.avatar ?? widget.leading ?? _avatar;
  }

  @override
  void dispose() {
    _above.dispose();
    _inline.dispose();
    _placement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_above, _inline, _placement]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final resolved = widget.resolve(context);
    final padding = resolved.resolvedPadding;
    final inline = _inline.value.clamp(0.0, 1.0);
    final text = DefaultTextStyle.of(context).style;
    final line =
        MediaQuery.textScalerOf(context).scale(text.fontSize ?? 17) *
        (text.height ?? 1.2);
    final plainHeight = math.max(
      resolved.resolvedMinHeight,
      line + padding.vertical,
    );
    final inlineHeight = math.max(
      plainHeight,
      resolved.resolvedLeadingSize + resolved.resolvedLeadingPadding.vertical,
    );
    final height = plainHeight + (inlineHeight - plainHeight) * inline;
    final around = resolved.resolvedLeadingPadding;
    final inset = EdgeInsetsGeometry.lerp(
      padding,
      EdgeInsetsDirectional.only(start: around.start, end: padding.right),
      inline,
    )!;
    final content = SizedBox(
      height: math.max(0, height - inset.vertical),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: (resolved.resolvedLeadingSize + around.end) * inline,
            height: resolved.resolvedLeadingSize,
            child: widget.avatar != null && widget.leading != null
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SizedBox.square(
                      dimension: resolved.resolvedLeadingSize,
                      child: widget.leading,
                    ),
                  )
                : null,
          ),
          Flexible(child: widget.child),
        ],
      ),
    );
    final glass = resolved.glass ?? Glass.regular;
    final Widget capsule = widget.onPressed == null
        ? LiquidPrism(
            glass: glass,
            shape: GlassShape.capsule,
            child: Padding(padding: inset, child: content),
          )
        : LiquidPrismPressable.glass(
            onPressed: widget.onPressed,
            label:
                widget.semanticLabel ??
                switch (widget.child) {
                  Text(:final data?) => data,
                  _ => '',
                },
            child: LiquidPrism(
              glass: glass.interactive(false),
              role: GlassRole.button,
              shape: GlassShape.capsule,
              child: Padding(
                padding: inset,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                  ),
                  child: content,
                ),
              ),
            ),
          );
    final avatar = _avatar;
    final above = math.max(0.0, _above.value);
    final size = resolved.resolvedAvatarSize;
    final overlap = math.min(resolved.resolvedAvatarOverlap, size);
    return GlassGroupMembers(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: (size - overlap) * above),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              capsule,
              if (avatar != null)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final placement = _placement.value;
                      final presence = (_above.value + _inline.value).clamp(
                        0.0,
                        1.0,
                      );
                      final dimension = math.max(
                        0.0,
                        size +
                            (resolved.resolvedLeadingSize - size) * placement,
                      );
                      final rtl =
                          Directionality.of(context) == TextDirection.rtl;
                      final inlineX = rtl
                          ? constraints.maxWidth - around.start - dimension
                          : around.start;
                      final x =
                          (constraints.maxWidth - dimension) /
                              2 *
                              (1 - placement) +
                          inlineX * placement;
                      // Interpolate in the title's coordinates, then remove the
                      // capsule's animated offset so it cannot bend the path.
                      final y =
                          size / 2 * (1 - placement) +
                          inlineHeight / 2 * placement -
                          dimension / 2 -
                          (size - overlap) * above;
                      final hidden =
                          widget.avatar == null && widget.leading == null;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: x,
                            top: y,
                            width: dimension,
                            height: dimension,
                            child: IgnorePointer(
                              ignoring:
                                  hidden ||
                                  (widget.avatar == null &&
                                      widget.onPressed != null),
                              child: ExcludeSemantics(
                                excluding: hidden,
                                child: ExcludeFocus(
                                  excluding: hidden,
                                  child: Opacity(
                                    opacity: presence,
                                    child: Transform.scale(
                                      scale: .8 + .2 * presence,
                                      child: FittedBox(
                                        child: SizedBox.square(
                                          dimension: math.max(
                                            size,
                                            resolved.resolvedLeadingSize,
                                          ),
                                          child: avatar,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
