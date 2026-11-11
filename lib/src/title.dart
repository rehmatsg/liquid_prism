import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show internal;

import 'motion.dart';
import 'pressable.dart';
import 'recipe.dart';
import 'glass.dart';
import 'glass_transition.dart';
import 'material.dart';
import 'theme.dart';

const titleCompositionSpring = GlassSpring(
  response: Duration(milliseconds: 300),
  bounce: .22,
);

/// Bar control geometry and subtitle composition for a glass title capsule.
@internal
class GlassTitleLayout extends InheritedWidget {
  const GlassTitleLayout({
    super.key,
    required this.subtitle,
    required this.style,
    required this.controlHeight,
    required super.child,
  });
  final Widget? subtitle;
  final double controlHeight;
  final TextStyle style;
  static GlassTitleLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassTitleLayout>();
  @override
  bool updateShouldNotify(GlassTitleLayout oldWidget) =>
      subtitle != oldWidget.subtitle ||
      style != oldWidget.style ||
      controlHeight != oldWidget.controlHeight;
}

/// Geometry of a [LiquidPrismTitle]. Null fields inherit the theme's
/// `GlassNavigationBarStyle.titleCapsule`, then the component defaults.
/// Inline capsules match the bar controls (44 points on a top bar, 48 on a
/// rail); default vertical insets adapt to the text and leading slot. Larger
/// text, explicit insets and minimum heights can require more space.
/// Above-avatar headers use a 64-point avatar, a 6-point overlap, a capsule
/// at least 38 points tall and 14 x 9 points of title padding. The default
/// inline leading size is 22 points, with a 12-point start and 10-point gap.
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
  /// points tall: the capsule, and the avatar above it. [controlHeight]
  /// supplies the bar's icon-button height for inline compositions.
  static double extentOf(
    LiquidPrismTitle title,
    GlassTitleStyle style,
    double lineHeight, {
    double subtitleHeight = 0,
    double controlHeight = 44,
  }) {
    return _capsuleHeight(
          title,
          style,
          lineHeight + subtitleHeight,
          controlHeight,
        ) +
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
    double controlHeight,
  ) {
    final metrics = _titleMetrics(
      style,
      lineHeight,
      controlHeight,
      compact: title.avatar == null,
    );
    return title.leading == null ? metrics.plainHeight : metrics.inlineHeight;
  }

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
    final layout = GlassTitleLayout.maybeOf(context);
    final subtitle = layout?.subtitle;
    final inline = _inline.value.clamp(0.0, 1.0);
    final text = DefaultTextStyle.of(context).style;
    final line =
        MediaQuery.textScalerOf(context).scale(text.fontSize ?? 17) *
        (text.height ?? 1.2);
    final subtitleHeight = subtitle == null
        ? 0.0
        : MediaQuery.textScalerOf(context).scale(layout!.style.fontSize ?? 12) *
                  (layout.style.height ?? 1.2) +
              2;
    final natural = _titleMetrics(
      resolved,
      line + subtitleHeight,
      layout?.controlHeight ?? 44,
      compact: false,
    );
    final compact = _titleMetrics(
      resolved,
      line + subtitleHeight,
      layout?.controlHeight ?? 44,
      compact: true,
    );
    final above = _above.value.clamp(0.0, 1.0);
    final padding = EdgeInsets.lerp(compact.padding, natural.padding, above)!;
    final around = compact.around;
    final inlineHeight = compact.inlineHeight;
    final height =
        natural.plainHeight +
        (inlineHeight - natural.plainHeight) * inline +
        (compact.plainHeight - natural.plainHeight) *
            (1 - above - inline).clamp(0.0, 1.0);
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
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: widget.leading == null
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                widget.child,
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle(
                    style: layout!.style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: subtitle,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final glass = resolved.glass ?? Glass.regular;
    final Widget capsule = widget.onPressed == null
        ? LiquidPrism(
            glass: glass,
            role: GlassRole.toolbar,
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
              child: Padding(padding: inset, child: content),
            ),
          );
    final avatar = _avatar;
    final aboveExtent = math.max(0.0, _above.value);
    final size = resolved.resolvedAvatarSize;
    final overlap = math.min(resolved.resolvedAvatarOverlap, size);
    return GlassGroupMembers(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: (size - overlap) * aboveExtent),
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
                      final widthChange =
                          resolved.resolvedLeadingSize +
                          around.end +
                          around.start -
                          padding.left;
                      // Keep the destination fixed while the capsule changes width.
                      final inlineWidth =
                          constraints.maxWidth + widthChange * (1 - inline);
                      final inlineCenter =
                          around.start +
                          resolved.resolvedLeadingSize / 2 -
                          inlineWidth / 2;
                      final x =
                          constraints.maxWidth / 2 +
                          (rtl ? -inlineCenter : inlineCenter) * placement -
                          dimension / 2;
                      // Interpolate in the title's coordinates, then remove the
                      // capsule's animated offset so it cannot bend the path.
                      final y =
                          size / 2 * (1 - placement) +
                          inlineHeight / 2 * placement -
                          dimension / 2 -
                          (size - overlap) * aboveExtent;
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
                                  child: GlassContentPresence(
                                    presence:
                                        presence *
                                        LiquidPrismPresence.of(context),
                                    blur:
                                        LiquidPrismPresence.maybeData(context)
                                            ?.contentBlur ??
                                        0,
                                    child: Transform.scale(
                                      scale: .8 + .2 * presence,
                                      child: FittedBox(
                                        child: SizedBox.square(
                                          dimension: widget.avatar != null
                                              ? size
                                              : resolved.resolvedLeadingSize,
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

({
  EdgeInsets padding,
  EdgeInsetsDirectional around,
  double plainHeight,
  double inlineHeight,
})
_titleMetrics(
  GlassTitleStyle style,
  double textHeight,
  double controlHeight, {
  required bool compact,
}) {
  var padding = style.resolvedPadding;
  var around = style.resolvedLeadingPadding;
  if (compact) {
    if (style.padding == null) {
      final vertical = math.min(
        padding.top,
        math.max(0.0, (controlHeight - textHeight) / 2),
      );
      padding = padding.copyWith(top: vertical, bottom: vertical);
    }
    if (style.leadingPadding == null) {
      final vertical = math.min(
        around.top,
        math.max(0.0, (controlHeight - style.resolvedLeadingSize) / 2),
      );
      around = around.copyWith(top: vertical, bottom: vertical);
    }
  }
  final plainHeight = math.max(
    math.max(style.resolvedMinHeight, compact ? controlHeight : 0.0),
    textHeight + padding.vertical,
  );
  return (
    padding: padding,
    around: around,
    plainHeight: plainHeight,
    inlineHeight: math.max(
      plainHeight,
      style.resolvedLeadingSize + around.vertical,
    ),
  );
}
