import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_colors.dart';
import 'package:liquid_prism/src/theme/typography.dart';

/// Badge indicator displayed on a tab or toolbar item.
@immutable
final class PrismBadge {
  /// Creates a compact activity dot badge.
  const new dot({this.semanticLabel = 'New activity'})
    : count = null,
      overflow = null,
      label = null;

  /// Creates a numeric count badge with optional [overflow] cap.
  const new count(int this.count, {this.overflow, String? semanticLabel})
    : assert(count >= 0, 'count must be non-negative.'),
      assert(overflow == null || overflow > 0, 'overflow must be positive.'),
      label = null,
      semanticLabel = semanticLabel ?? '$count';

  /// Creates a badge displaying short custom text.
  const new text(String this.label, {String? semanticLabel})
    : count = null,
      overflow = null,
      semanticLabel = semanticLabel ?? label;

  /// Numeric count, if constructed with [PrismBadge.count].
  final int? count;

  /// Maximum count displayed before appending `+`.
  final int? overflow;

  /// Custom text label, if constructed with [PrismBadge.text].
  final String? label;

  /// Accessible announcement for this badge.
  final String semanticLabel;

  /// Rendered badge text, or null for [PrismBadge.dot].
  String? get text {
    if (label != null) return label;
    final value = count;
    if (value == null) return null;
    final cap = overflow;
    if (cap != null && value > cap) return '${_grouped(cap)}+';
    return _grouped(value);
  }

  static String _grouped(int value) {
    final digits = '$value';
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrismBadge &&
          other.count == count &&
          other.overflow == overflow &&
          other.label == label &&
          other.semanticLabel == semanticLabel;

  @override
  int get hashCode => Object.hash(count, overflow, label, semanticLabel);
}

@internal
class PrismBadgeView extends StatelessWidget {
  const new({
    super.key,
    required this.badge,
    this.height = 18.33,
    this.color,
    this.textStyle,
  });

  final PrismBadge badge;
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
            color: color ?? PrismColors.of(context).red,
            shape: const StadiumBorder(),
          ),
          alignment: Alignment.center,
          child: text == null
              ? null
              : Text(
                  text,
                  maxLines: 1,
                  softWrap: false,
                  style: prismTextStyle(
                    context,
                    const TextStyle(
                      fontSize: 12,
                      height: 14.33 / 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFFFFFFF),
                    ),
                  ).merge(textStyle),
                ),
        ),
      ),
    );
  }
}

@internal
class PrismBadgedIcon extends StatelessWidget {
  const new({
    super.key,
    required this.child,
    this.badge,
    this.color,
    this.textStyle,
  });

  final Widget child;
  final PrismBadge? badge;
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
          top: size / 2 - 24.5 + 18.33 / 2,
          start: size - 5 + 18.33 / 2,
          child: FractionalTranslation(
            translation: Offset(
              Directionality.of(context) == TextDirection.rtl ? .5 : -.5,
              -.5,
            ),
            child: PrismBadgeView(
              badge: badge,
              color: color,
              textStyle: textStyle,
            ),
          ),
        ),
      ],
    );
  }
}
