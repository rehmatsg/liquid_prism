import 'package:flutter/widgets.dart';

import 'material.dart';
import 'native_colors.dart';
import 'style.dart';

// Native RGB tint matrices; explicit custom colors retain the legacy fallback.
enum GlassRole {
  surface(0),
  button(1),
  tabBar(2),
  tabLens(3),
  controlThumb(4),
  segmentLens(5),
  toolbar(7),
  searchField(8),
  sliderLens(9);

  // Preserve shader IDs when a component is removed from the enum.
  const GlassRole(this.shaderId);
  final double shaderId;
}

final class GlassRecipe {
  const GlassRecipe(
    this.kind,
    this.dark,
    this.role,
    this.tintMatrix,
    this.tintAlpha,
  );
  final double kind;
  final bool dark;
  final GlassRole role;

  /// Three RGB rows with normalized offsets (12 values).
  final List<double> tintMatrix;
  final double tintAlpha;

  // Native controls retain their captured profile. The requested half-strength
  // Regular/Clear balance applies to standalone surfaces.
  bool get usesNativeControlShadow => kind != 0 && role != GlassRole.surface;
  double get shadowStrength =>
      kind == 3 ? 0 : (usesNativeControlShadow ? 1 : (kind == 1 ? 0.5 : 1));
  static GlassRecipe resolve(
    Glass glass,
    Brightness brightness,
    GlassRole role, {
    required bool customOptics,
  }) {
    final dark = brightness == Brightness.dark;
    final tint = glass.tintColor;
    final rgb = tint == null ? 0 : tint.toARGB32() & 0xFFFFFF;
    final matrix =
        nativeTintMatrices[(glass.variant == GlassVariant.clear, dark, rgb)];
    // Arbitrary colors (and unmeasured clear accents) retain app-owned styling.
    // This fallback is not an extracted Apple matrix.
    final fallback = <double>[
      for (final component in [tint?.r ?? 0, tint?.g ?? 0, tint?.b ?? 0]) ...[
        0.12 * (1 - component) * 0.2126,
        0.12 * (1 - component) * 0.7152,
        0.12 * (1 - component) * 0.0722,
        component * 0.94,
      ],
    ];
    return GlassRecipe(
      (role == GlassRole.toolbar || role == GlassRole.searchField)
          ? (glass.variant == GlassVariant.clear ? 2 : 1)
          : (role == GlassRole.controlThumb ||
                role == GlassRole.segmentLens ||
                role == GlassRole.tabLens ||
                role == GlassRole.sliderLens)
          ? 3
          : customOptics
          ? 0
          : (glass.variant == GlassVariant.clear ? 2 : 1),
      dark,
      role,
      matrix ?? fallback,
      tint?.a ?? 0,
    );
  }

  LiquidPrismStyle optics(double radius) => kind == 2
      ? LiquidPrismStyle.clear.copyWith(
          cornerRadius: radius,
          tint: const Color(0x00000000),
          brightness: 0,
          saturation: 1,
        )
      : LiquidPrismStyle(
          refraction: 48,
          frost: 3.3,
          brightness: 0,
          tint: const Color(0x00000000),
          saturation: 1,
          reflection: 0.08,
          cornerRadius: radius,
        );
  List<double> get uniforms => [
    kind,
    dark ? 1 : 0,
    role.shaderId,
    tintAlpha,
    ...tintMatrix,
    0, 0, 0, 0, // Press progress, smooth contour flag, reserved.
  ];
}

/// Extracted iOS 27 glassBackground shadow inputs. Kernel conversion belongs to
/// the renderer; these retain the native radius and separate color alpha.
final class NativeGlassShadow {
  const NativeGlassShadow(this.radius, this.opacity);
  final double radius;
  final double opacity;
  static const control = NativeGlassShadow(4, 0.03999999910593033);
  static const colorAlpha = 0.30000001192092896;
  static const offset = 8.0;
  static const ringWidth = 4.0;
  static const ringRadius = 5.0;
  static const ringOpacity = 0.05999999865889549;

  factory NativeGlassShadow.resolve(double extent, {required bool dark}) {
    final progress = ((extent - 64) / 96).clamp(0.0, 1.0);
    const smallOpacity = 0.03999999910593033;
    final largeOpacity = dark ? 0.6000000238418579 : 0.4000000059604645;
    return NativeGlassShadow(
      4 + 20 * progress,
      smallOpacity + (largeOpacity - smallOpacity) * progress,
    );
  }
}
