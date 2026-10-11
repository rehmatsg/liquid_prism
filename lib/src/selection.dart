import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';
import 'material.dart';
import 'native_colors.dart';

/// Native-style selected-tab material, with no rim or independent glass lens.
/// Adds a small independent blur and grades the glass underneath, keeping
/// foreground content sharp even when the enclosing bar has no blur.
class LiquidPrismSelection extends StatelessWidget {
  const LiquidPrismSelection({
    super.key,
    required this.selected,
    required this.child,
    this.shape = GlassShape.capsule,
    this.color,
    this.blur = 2,
  }) : assert(blur >= 0 && blur <= 12);
  final bool selected;
  final Widget child;
  final GlassShape shape;
  final Color? color;

  /// Additional backdrop blur in logical pixels, independent of the bar.
  final double blur;
  @override
  Widget build(BuildContext context) {
    final dark =
        LiquidPrismTheme.materialBrightnessOf(context) == Brightness.dark;
    if (!selected) return child;
    final matrix = dark ? nativeDarkSelection : nativeLightSelection;
    final fill = color;
    final content = fill != null
        ? BackdropFilter(
            enabled: blur > 0,
            filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: ColoredBox(color: fill, child: child),
          )
        : BackdropFilter(
            filter: ui.ImageFilter.compose(
              outer: ui.ColorFilter.matrix(matrix),
              inner: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            ),
            child: child,
          );
    return ClipPath(clipper: GlassShapeClipper(shape), child: content);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      FlagProperty('selected', value: selected, ifTrue: 'selected'),
    );
    properties.add(DoubleProperty('blur', blur));
  }
}
