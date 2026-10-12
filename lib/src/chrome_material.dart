import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'material.dart';
import 'recipe.dart';
import 'style.dart';
import 'theme.dart';

/// Native navigation/search capsule inputs; see doc/native_chrome_spec.md.
class ChromeMaterial extends StatelessWidget {
  const ChromeMaterial({
    super.key,
    required this.height,
    required this.role,
    required this.child,
    this.glass,
    this.optics,
    this.blur,
    this.shape,
  });
  final double height;
  final GlassRole role;
  final Widget child;
  final Glass? glass;
  final LiquidPrismStyle? optics;
  final double? blur;
  final GlassShape? shape;
  @override
  Widget build(BuildContext context) {
    final theme = LiquidPrismTheme.of(context);
    return LiquidPrism(
      glass: (glass ?? theme.glass ?? Glass.regular).interactive(false),
      shape: shape ?? GlassShape.capsule,
      role: role,
      blur: blur ?? optics?.frost ?? theme.blur ?? theme.optics?.frost ?? 5,
      optics:
          optics ??
          theme.optics ??
          LiquidPrismStyle(
            edgeWidth: height / 4,
            refraction: height / 2,
            frost: 5,
            reflection: .08,
            dispersion: 0,
            brightness: 0,
            saturation: 1,
            tint: const Color(0x00000000),
          ),
      child: child,
    );
  }
}
