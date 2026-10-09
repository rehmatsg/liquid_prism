import 'package:flutter/widgets.dart';

import 'system_glass.dart';

/// Native backdrops are outside Flutter's texture. The current iOS resting
/// palette avoids readback or an extra optical pass for foregrounds.
bool usesRestingGlassPalette(BuildContext context) =>
    SystemGlassBackground.of(context) || SystemGlass.appearanceVersion >= 27;

/// Default normal-contrast foreground palette. iOS adapts its
/// actual pixels to the backdrop; this inexpensive palette is an approximation.
Color restingGlassAccent(Color tint, Brightness brightness) {
  if (tint.a < 1) return tint;
  final dark = brightness == Brightness.dark;
  final modern = SystemGlass.appearanceVersion >= 27;
  final systemBlue = dark ? const Color(0xFF0091FF) : const Color(0xFF0088FF);
  if (tint.toARGB32() == systemBlue.toARGB32()) {
    return Color(
      dark
          ? (modern ? 0xFF3BCCFF : 0xFF14DAFF)
          : (modern ? 0xFF005DC7 : 0xFF0065DF),
    );
  }
  return Color.from(
    alpha: tint.a,
    red: dark ? (tint.r + .23).clamp(0, 1) : tint.r * .75,
    green: dark ? (tint.g + .23).clamp(0, 1) : tint.g * .75,
    blue: dark ? (tint.b + .23).clamp(0, 1) : tint.b * .75,
  );
}
