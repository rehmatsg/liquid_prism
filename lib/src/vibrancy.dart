import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'system_glass.dart';

/// Applies the accent matrix to the backdrop through the content mask.
/// Each pass contains foreground only; the glass stays outside its saveLayers.
class GlassVibrantForeground extends SingleChildRenderObjectWidget {
  const GlassVibrantForeground({
    super.key,
    required this.tint,
    required this.brightness,
    this.enabled = true,
    required super.child,
  });
  final bool enabled;
  final Color tint;
  final Brightness brightness;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderVibrancy(
    tint,
    brightness,
    SystemGlassBackground.of(context),
    enabled,
  );
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) {
    (renderObject as _RenderVibrancy)
      ..enabled = enabled
      ..native = SystemGlassBackground.of(context)
      ..tint = tint
      ..brightness = brightness
      ..markNeedsPaint();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('tint', tint))
      ..add(EnumProperty('brightness', brightness));
  }
}

class _RenderVibrancy extends RenderProxyBox {
  _RenderVibrancy(this.tint, this.brightness, this.native, this.enabled);
  bool enabled;
  bool native;
  Color tint;
  Brightness brightness;
  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    // Composited/custom foregrounds retain their normal source color. Ordinary
    // text, icons and rows paint into this display list and support the mask.
    if (!enabled || native || child!.needsCompositing || tint.a < 1) {
      super.paint(context, offset);
      return;
    }
    final dark = brightness == Brightness.dark;
    final bias = dark ? 0.0 : 1.0;
    final base = Color.from(
      alpha: .75,
      red: (2 * tint.r + bias) / 3,
      green: (2 * tint.g + bias) / 3,
      blue: (2 * tint.b + bias) / 3,
    );
    final bounds = offset & size;
    context.canvas.saveLayer(
      bounds,
      Paint()..colorFilter = ColorFilter.mode(base, BlendMode.srcIn),
    );
    context.paintChild(child!, offset);
    context.canvas.restore();
    context.canvas.saveLayer(
      bounds,
      Paint()
        ..colorFilter = const ColorFilter.mode(
          Color.from(alpha: 1, red: .5, green: .5, blue: .5),
          BlendMode.srcIn,
        )
        ..blendMode = dark ? BlendMode.colorDodge : BlendMode.colorBurn,
    );
    context.paintChild(child!, offset);
    context.canvas.restore();
  }
}
