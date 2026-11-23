import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_optics.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/surface.dart';
import 'package:liquid_prism/src/theme/prism_theme.dart';

/// Native navigation and search capsule material inputs.
@internal
class ChromeMaterial extends StatelessWidget {
  const new({
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
  final PrismRole role;
  final Widget child;
  final PrismGlass? glass;
  final PrismOptics? optics;
  final double? blur;
  final PrismShape? shape;
  @override
  Widget build(BuildContext context) {
    final theme = PrismTheme.of(context);
    final ownOptics = optics ?? theme.optics;
    return RawPrismSurface(
      glass: (glass ?? theme.glass ?? PrismGlass.regular).interactive(false),
      shape: shape ?? PrismShape.capsule,
      role: role,
      blur: blur ?? ownOptics?.frost ?? theme.blur,
      materialOptics: ownOptics == null,
      optics:
          ownOptics ??
          PrismOptics(
            edgeWidth: height / 4,
            refraction: height / 2,
            frost: PrismRecipe.regularFrost,
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
