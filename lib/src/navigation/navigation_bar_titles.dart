import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/navigation/prism_navigation_bar_style.dart';
import 'package:liquid_prism/src/navigation/prism_title.dart';

@internal
class PrismNavigationTitles {
  new({
    required Widget? title,
    required Widget? largeTitle,
    required PrismNavigationBarStyle style,
    required bool rail,
    required bool horizontalDuo,
    required bool customTitle,
  }) {
    final mode = style.titleDisplayMode ?? PrismTitleDisplayMode.automatic;
    final automatic = mode == PrismTitleDisplayMode.automatic;
    final preferred = largeTitle ?? title;
    final usesExpandedRow =
        mode == PrismTitleDisplayMode.large && !rail ||
        automatic &&
            (rail
                ? style.largeTitleExtent != null && largeTitle != null
                : largeTitle != null || horizontalDuo && !customTitle);
    expanded = usesExpandedRow ? preferred : null;
    final usesLargeInRow =
        !usesExpandedRow &&
        (mode == PrismTitleDisplayMode.inlineLarge ||
            rail &&
                (mode == PrismTitleDisplayMode.large ||
                    automatic && (!customTitle || largeTitle != null)));
    largeInRow = usesLargeInRow ? preferred : null;
    compact = title ?? (automatic && !rail ? null : largeTitle);
    compactStyle = style.titleStyle;
    largeStyle = largeTitle == null
        ? style.largeTitleStyle?.merge(style.titleStyle) ?? style.titleStyle
        : style.largeTitleStyle;
  }

  late final Widget? expanded;
  late final Widget? largeInRow;
  late final Widget? compact;
  late final TextStyle? compactStyle;
  late final TextStyle? largeStyle;

  Widget? get inRow => largeInRow ?? compact;
}

@internal
TextStyle prismNavigationTitleTypography({
  required bool large,
  required bool rail,
  required bool hasSubtitle,
  required Color color,
  TextStyle? override,
}) => TextStyle(
  fontFamily: large ? 'CupertinoSystemDisplay' : 'CupertinoSystemText',
  fontSize: large
      ? (rail ? (hasSubtitle ? 22 : 28) : 34)
      : (hasSubtitle ? 15 : 17),
  fontWeight: large ? FontWeight.w700 : FontWeight.w600,
  letterSpacing: large ? (rail ? 0 : .38) : (hasSubtitle ? -.23 : -.41),
  color: color,
).merge(override);

@internal
TextStyle prismNavigationSubtitleTypography({
  required bool large,
  required Color color,
  TextStyle? override,
}) => TextStyle(
  fontSize: large ? 11 : 12,
  fontWeight: large ? FontWeight.w500 : null,
  color: color,
).merge(override);

@internal
Widget prismNavigationTitleSlot({
  required Listenable motion,
  required bool Function() visible,
  required Widget child,
}) => AnimatedBuilder(
  animation: motion,
  builder: (context, child) => visible() ? child! : const SizedBox.shrink(),
  child: child,
);

@internal
Widget prismNavigationPinnedTitle({
  required Widget title,
  required Widget compact,
  required Widget? subtitle,
  required TextStyle largeStyle,
  required TextStyle compactStyle,
  required TextStyle largeSubtitleStyle,
  required TextStyle compactSubtitleStyle,
  required PrismTitleAlignment alignment,
  required bool collapsed,
  required double controlHeight,
  required Widget Function(Widget, TextStyle) decorate,
}) {
  final textAlignment = alignment == PrismTitleAlignment.automatic
      ? PrismTitleAlignment.center
      : alignment;
  Widget styled(Widget child, {required bool large}) => decorate(
    prismTitled(
      child,
      large != collapsed ? subtitle : null,
      large ? largeSubtitleStyle : compactSubtitleStyle,
      large: false,
      alignment: textAlignment,
      controlHeight: controlHeight,
    ),
    large ? largeStyle : compactStyle,
  );
  if (identical(title, compact)) return styled(title, large: !collapsed);
  return Stack(
    alignment: prismTitleBoxAlignment(textAlignment),
    children: [
      ExcludeFocus(
        excluding: collapsed,
        child: Offstage(offstage: collapsed, child: styled(title, large: true)),
      ),
      ExcludeFocus(
        excluding: !collapsed,
        child: Offstage(
          offstage: !collapsed,
          child: styled(compact, large: false),
        ),
      ),
    ],
  );
}

@internal
Widget prismTitled(
  Widget title,
  Widget? subtitle,
  TextStyle subtitleStyle, {
  required bool large,
  PrismTitleAlignment alignment = PrismTitleAlignment.center,
  double subtitleOffset = 0,
  double controlHeight = 44,
}) {
  if (!large && title is PrismTitle) {
    return _FitsRow(
      child: PrismTitleLayout(
        subtitle: subtitle,
        style: subtitleStyle,
        controlHeight: controlHeight,
        child: title,
      ),
    );
  }
  if (!large) {
    return _FitsRow(child: _titled(title, subtitle, subtitleStyle, alignment));
  }
  if (subtitle == null) return title;
  final line = DefaultTextStyle(
    style: subtitleStyle,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    child: subtitle,
  );
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: prismTitleCrossAlignment(alignment),
    children: [
      SizedBox(
        height: subtitleOffset,
        child: OverflowBox(
          alignment: prismTitleBoxAlignment(alignment),
          maxHeight: double.infinity,
          child: title,
        ),
      ),
      line,
    ],
  );
}

Widget _titled(
  Widget title,
  Widget? subtitle,
  TextStyle subtitleStyle,
  PrismTitleAlignment alignment,
) {
  if (subtitle == null) return title;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: prismTitleCrossAlignment(alignment),
    children: [
      title,
      DefaultTextStyle(
        style: subtitleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: subtitle,
      ),
    ],
  );
}

@internal
PrismTitleAlignment prismDefaultTitleAlignment({
  required PrismTitleAlignment? requested,
  required bool glassTitle,
  required int actions,
  required bool foldedRail,
  required bool sheet,
}) => requested != null && requested != PrismTitleAlignment.automatic
    ? requested
    : glassTitle
    ? PrismTitleAlignment.center
    : actions > 1
    ? PrismTitleAlignment.leading
    : foldedRail && !sheet
    ? PrismTitleAlignment.leading
    : PrismTitleAlignment.automatic;

@internal
PrismTitleAlignment prismResolvedTitleAlignment(
  PrismTitleAlignment alignment,
  double titleWidth,
  double centeredWidth,
) => alignment != PrismTitleAlignment.automatic
    ? alignment
    : titleWidth <= centeredWidth + 1e-6
    ? PrismTitleAlignment.center
    : PrismTitleAlignment.leading;

@internal
AlignmentGeometry prismTitleBoxAlignment(PrismTitleAlignment alignment) =>
    switch (alignment) {
      PrismTitleAlignment.center => Alignment.topCenter,
      PrismTitleAlignment.trailing => AlignmentDirectional.topEnd,
      _ => AlignmentDirectional.topStart,
    };

@internal
CrossAxisAlignment prismTitleCrossAlignment(PrismTitleAlignment alignment) =>
    switch (alignment) {
      PrismTitleAlignment.center => CrossAxisAlignment.center,
      PrismTitleAlignment.trailing => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };

class _FitsRow extends SingleChildRenderObjectWidget {
  const new({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFitsRow();
}

class _RenderFitsRow extends RenderProxyBox {
  double _scale = 1;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      BoxConstraints(maxWidth: constraints.maxWidth),
      parentUsesSize: true,
    );
    final height = child.size.height;
    _scale =
        constraints.hasBoundedHeight &&
            height > constraints.maxHeight &&
            height > 0
        ? constraints.maxHeight / height
        : 1;
    size = constraints.constrain(child.size * _scale);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final natural = child.getDryLayout(
      BoxConstraints(maxWidth: constraints.maxWidth),
    );
    final scale =
        constraints.hasBoundedHeight &&
            natural.height > constraints.maxHeight &&
            natural.height > 0
        ? constraints.maxHeight / natural.height
        : 1.0;
    return constraints.constrain(natural * scale);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (_scale == 1) return super.paint(context, offset);
    layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_scale == 1) return super.hitTestChildren(result, position: position);
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(_scale, _scale, 1),
      position: position,
      hitTest: (result, position) =>
          super.hitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(Matrix4.diagonal3Values(_scale, _scale, 1));
  }
}
