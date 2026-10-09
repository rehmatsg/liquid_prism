import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';
import 'material.dart';
import 'system_glass.dart';

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
    final dark = LiquidPrismTheme.brightnessOf(context) == Brightness.dark;
    if (!selected) return child;
    final modern = SystemGlass.appearanceVersion >= 27;
    final matrix = dark ? (modern ? _dark27 : _dark) : _light;
    final fill =
        color ??
        (SystemGlassBackground.of(context)
            ? Color(dark ? (modern ? 0x38000000 : 0x24FFFFFF) : 0x30000000)
            : null);
    final content = fill != null
        ? BackdropFilter(
            enabled: blur > 0,
            // iOS platform views support a blur-only backdrop filter;
            // composing a color filter would disable that native blur.
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
    // These clip primitives reach iOS's native backdrop blur. ClipPath does
    // not, and would soften a rectangular area outside the selection corners.
    return shape.isSmooth
        ? ClipRSuperellipse(
            borderRadius: BorderRadius.circular(shape.radius),
            child: content,
          )
        : ClipRRect(clipper: _SelectionClipper(shape), child: content);
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

class _SelectionClipper extends CustomClipper<RRect> {
  const _SelectionClipper(this.shape);
  final GlassShape shape;
  @override
  RRect getClip(Size size) => shape.outline(size);
  @override
  bool shouldReclip(_SelectionClipper oldClipper) => shape != oldClipper.shape;
}

// Core Animation normalized offsets become Flutter's 0..255 color offsets.
const _dark = <double>[
  1.082,
  -.113,
  -.011,
  0,
  34.425,
  -.034,
  1.003,
  -.011,
  0,
  34.425,
  -.034,
  -.113,
  1.105,
  0,
  34.425,
  0,
  0,
  0,
  1,
  0,
];
const _light = <double>[
  1.185,
  -.05,
  -.005,
  0,
  -51,
  -.015,
  1.15,
  -.005,
  0,
  -51,
  -.015,
  -.05,
  1.195,
  0,
  -51,
  0,
  0,
  0,
  1,
  0,
];

// Dark selected-tab color adjustment for iOS 27 and later.
const _dark27 = <double>[
  1.1298,
  -.2361,
  -.0237,
  0,
  -17.85,
  -.0701,
  .964,
  -.0238,
  0,
  -17.85,
  -.0702,
  -.236,
  1.1762,
  0,
  -17.85,
  0,
  0,
  0,
  1,
  0,
];
