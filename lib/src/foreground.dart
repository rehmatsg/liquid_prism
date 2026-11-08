import 'package:flutter/widgets.dart';

/// Normal-contrast accents over the grouped page background. Native vibrancy
/// adapts to the backdrop; a fixed palette only approximates other backgrounds.
Color glassAccent(Color tint, Brightness brightness, {bool held = false}) {
  if (tint.a < 1) return tint;
  final dark = brightness == Brightness.dark;
  if (held && !dark) return tint;
  final systemBlue = dark ? const Color(0xFF0091FF) : const Color(0xFF0088FF);
  if (tint.toARGB32() == systemBlue.toARGB32()) {
    return Color(dark ? (held ? 0xFF27B8FF : 0xFF0697FF) : 0xFF0081F5);
  }
  return Color.from(
    alpha: tint.a,
    red: dark ? (tint.r + .23).clamp(0, 1) : tint.r * .75,
    green: dark ? (tint.g + .23).clamp(0, 1) : tint.g * .75,
    blue: dark ? (tint.b + .23).clamp(0, 1) : tint.b * .75,
  );
}
