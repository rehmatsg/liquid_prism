import 'package:flutter/widgets.dart';

import 'theme.dart';

/// A badge on a tab or toolbar item: a count, short text, or an empty badge.
///
/// Measured on iOS 27: an 18.33-point red capsule (18 points on toolbar
/// items) with 12-point medium white text and 4 points of padding each side.
/// Native counts are never shortened (1000 draws `1,000`); pass [overflow] to
/// cap one, e.g. `99+`. Accessibility announces the full count.
@immutable
final class GlassBadge {
  /// An empty badge: the capsule with no text, as a native space badge or
  /// toolbar indicator draws it.
  const GlassBadge.dot({this.semanticLabel = 'New activity'})
    : count = null,
      overflow = null,
      label = null;

  const GlassBadge.count(int this.count, {this.overflow, String? semanticLabel})
    : assert(count >= 0),
      assert(overflow == null || overflow > 0),
      label = null,
      semanticLabel = semanticLabel ?? '$count';

  /// Short custom text, such as a localized count.
  const GlassBadge.text(String this.label, {String? semanticLabel})
    : count = null,
      overflow = null,
      semanticLabel = semanticLabel ?? label;

  final int? count;

  /// Counts above this draw as `overflow+`. Null draws every count.
  final int? overflow;
  final String? label;
  final String semanticLabel;

  /// The drawn text; null for [GlassBadge.dot].
  String? get text {
    if (label != null) return label;
    final value = count;
    if (value == null) return null;
    final cap = overflow;
    if (cap != null && value > cap) return '${_grouped(cap)}+';
    return _grouped(value);
  }

  /// Groups thousands with a comma, as the iOS 27 en_US capture shows. Use
  /// [GlassBadge.text] for another locale's grouping.
  static String _grouped(int value) {
    final digits = '$value';
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}

/// The badge capsule. Callers place it; it adds no input or semantics.
class GlassBadgeView extends StatelessWidget {
  const GlassBadgeView({
    super.key,
    required this.badge,
    this.height = 18.33,
    this.color,
    this.textStyle,
  });
  final GlassBadge badge;
  final double height;
  final Color? color;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final text = badge.text;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final size = height * (text == null ? 1 : scale.clamp(1.0, 2.0));
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(minWidth: size, minHeight: size),
          padding: text == null
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 4),
          decoration: ShapeDecoration(
            color: color ?? GlassColors.of(context).red,
            shape: const StadiumBorder(),
          ),
          alignment: Alignment.center,
          child: text == null
              ? null
              : Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 14.33 / 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFFFFFF),
                  ).merge(textStyle),
                ),
        ),
      ),
    );
  }
}

/// A tab glyph with its badge: measured on iOS 27, the badge's leading edge
/// sits 5 points inside the glyph's trailing edge and its top 24.5 points
/// above the glyph's centre (2 points below the tab button's top).
class GlassBadgedIcon extends StatelessWidget {
  const GlassBadgedIcon({
    super.key,
    required this.child,
    this.badge,
    this.color,
    this.textStyle,
  });
  final Widget child;
  final GlassBadge? badge;
  final Color? color;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    if (badge == null) return child;
    final size = IconTheme.of(context).size ?? 24;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(
          top: size / 2 - 24.5,
          start: size - 5,
          child: GlassBadgeView(
            badge: badge,
            color: color,
            textStyle: textStyle,
          ),
        ),
      ],
    );
  }
}
