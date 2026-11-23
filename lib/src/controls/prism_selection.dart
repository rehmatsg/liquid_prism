import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/theme/native_colors.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// Selected-pill backdrop grading material without an independent glass rim.
class PrismSelection extends StatelessWidget {
  /// Creates a selection backdrop container around [child].
  const new({
    super.key,
    required this.selected,
    required this.child,
    this.shape = PrismShape.capsule,
    this.color,
    this.blur = 2,
  }) : assert(blur >= 0 && blur <= 12, 'Blur must be between 0 and 12.');

  /// Whether the selection material is active.
  final bool selected;

  /// Content displayed inside the selection pill.
  final Widget child;

  /// Contour shape of the selection clip.
  final PrismShape shape;

  /// Optional solid/translucent fill replacing the native selection matrix.
  final Color? color;

  /// Independent backdrop blur sigma in logical pixels.
  final double blur;

  @override
  Widget build(BuildContext context) {
    final dark = PrismTheme.materialBrightnessOf(context) == Brightness.dark;
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
    return ClipPath(clipper: PrismShapeClipper(shape), child: content);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'))
      ..add(DoubleProperty('blur', blur));
  }
}
