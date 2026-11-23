import 'dart:math' as math;

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/controls/prism_pressable.dart';
import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_motion.dart';
import 'package:liquid_prism/src/navigation/prism_title_style.dart';
import 'package:liquid_prism/src/rendering/glass_group.dart';
import 'package:liquid_prism/src/rendering/prism_transition.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

@internal
const titleCompositionSpring = PrismSpring(
  response: Duration(milliseconds: 300),
  bounce: .22,
);

@internal
class PrismTitleLayout extends InheritedWidget {
  const new({
    super.key,
    required this.subtitle,
    required this.style,
    required this.controlHeight,
    required super.child,
  });
  final Widget? subtitle;
  final double controlHeight;
  final TextStyle style;
  static PrismTitleLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrismTitleLayout>();
  @override
  bool updateShouldNotify(PrismTitleLayout oldWidget) =>
      subtitle != oldWidget.subtitle ||
      style != oldWidget.style ||
      controlHeight != oldWidget.controlHeight;
}

/// A navigation title capsule with optional inline leading content and avatar.
class PrismTitle extends StatefulWidget {
  /// Creates a title capsule with optional leading content and avatar.
  const new({
    super.key,
    required this.child,
    this.leading,
    this.avatar,
    this.onPressed,
    this.semanticLabel,
    this.style,
  });

  /// Content displayed inside this widget.
  final Widget child;

  /// Leading navigation control or inline title content.
  final Widget? leading;

  /// Avatar displayed above the title capsule.
  final Widget? avatar;

  /// Activation callback; null disables the action.
  final VoidCallback? onPressed;

  /// Optional accessible name for the title button.
  final String? semanticLabel;

  /// Local appearance overrides merged over the component theme.
  final PrismTitleStyle? style;

  /// Resolves the inherited title capsule style with local overrides.
  PrismTitleStyle resolve(BuildContext context) =>
      (PrismTheme.of(context).navigationBar?.titleCapsule ??
              const PrismTitleStyle())
          .merge(style);

  /// Measures title height including the capsule, subtitle, and avatar.
  static double extentOf(
    PrismTitle title,
    PrismTitleStyle style,
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
            : math.max<double>(
                0,
                style.resolvedAvatarSize - style.resolvedAvatarOverlap,
              ));
  }

  static double _capsuleHeight(
    PrismTitle title,
    PrismTitleStyle style,
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
  State<PrismTitle> createState() => _PrismTitleState();
}

class _PrismTitleState extends State<PrismTitle> with TickerProviderStateMixin {
  late final _above = RetargetablePrismSpring(vsync: this)
    ..value = widget.avatar == null ? 0 : 1;
  late final _inline = RetargetablePrismSpring(vsync: this)
    ..value = widget.leading == null ? 0 : 1;
  late final _placement = RetargetablePrismSpring(vsync: this)
    ..value = widget.avatar == null ? 1 : 0;
  Widget? _avatar;
  bool _immediate = false;

  void _sync() {
    _avatar = widget.avatar ?? widget.leading ?? _avatar;
    if (widget.avatar != null || widget.leading != null) {
      springPrism(
        _placement,
        widget.avatar == null ? 1 : 0,
        titleCompositionSpring.description,
        immediate: _immediate,
      );
    }
    springPrism(
      _above,
      widget.avatar == null ? 0 : 1,
      titleCompositionSpring.description,
      immediate: _immediate,
    );
    springPrism(
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
  void didUpdateWidget(PrismTitle oldWidget) {
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
    final layout = PrismTitleLayout.maybeOf(context);
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
      height: math.max<double>(0, height - inset.vertical),
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
    final glass = resolved.glass ?? PrismGlass.regular;
    final Widget capsule = widget.onPressed == null
        ? RawPrismSurface(
            glass: glass,
            role: PrismRole.toolbar,
            shape: PrismShape.capsule,
            child: Padding(padding: inset, child: content),
          )
        : PrismPressable.glass(
            onPressed: widget.onPressed,
            label:
                widget.semanticLabel ??
                switch (widget.child) {
                  Text(:final data?) => data,
                  _ => '',
                },
            child: RawPrismSurface(
              glass: glass.interactive(false),
              role: PrismRole.button,
              shape: PrismShape.capsule,
              child: Padding(padding: inset, child: content),
            ),
          );
    final avatar = _avatar;
    final aboveExtent = math.max<double>(0, _above.value);
    final size = resolved.resolvedAvatarSize;
    final overlap = math.min(resolved.resolvedAvatarOverlap, size);
    return PrismGroupMembers(
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
                      final dimension = math.max<double>(
                        0,
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
                                  child: PrismContentPresence(
                                    presence:
                                        presence * PrismPresence.of(context),
                                    blur:
                                        PrismPresence.maybeData(context)
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
  PrismTitleStyle style,
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
        math.max<double>(0, (controlHeight - textHeight) / 2),
      );
      padding = padding.copyWith(top: vertical, bottom: vertical);
    }
    if (style.leadingPadding == null) {
      final vertical = math.min(
        around.top,
        math.max<double>(0, (controlHeight - style.resolvedLeadingSize) / 2),
      );
      around = around.copyWith(top: vertical, bottom: vertical);
    }
  }
  final plainHeight = math.max(
    math.max(style.resolvedMinHeight, compact ? controlHeight : 0.0),
    textHeight + padding.vertical,
  );
  final inlineHeight = math.max(
    plainHeight,
    style.resolvedLeadingSize + around.vertical,
  );
  if (style.leadingPadding == null) {
    final vertical = (inlineHeight - style.resolvedLeadingSize) / 2;
    around = EdgeInsetsDirectional.fromSTEB(
      inlineHeight / 2 - style.resolvedLeadingCornerRadius,
      vertical,
      around.end,
      vertical,
    );
  }
  return (
    padding: padding,
    around: around,
    plainHeight: plainHeight,
    inlineHeight: inlineHeight,
  );
}
