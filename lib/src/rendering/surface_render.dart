import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:liquid_prism/src/core/prism_glass.dart';
import 'package:liquid_prism/src/core/prism_optics.dart';
import 'package:liquid_prism/src/rendering/glass_group.dart';
import 'package:liquid_prism/src/rendering/layer_transform.dart';
import 'package:liquid_prism/src/rendering/prism.dart';
import 'package:liquid_prism/src/rendering/prism_display.dart';
import 'package:liquid_prism/src/rendering/recipe.dart';
import 'package:liquid_prism/src/rendering/superellipse.dart';

@internal
bool isHDRSurface(PrismRecipe recipe) =>
    PrismDisplay.headroom.value > 1 && recipe.kind == 1 && !recipe.dark;

/// Writes the chromatic fringe values into the surface shader packet.
@visibleForTesting
void writeChromaticFringeUniforms(
  List<double> values,
  PrismRecipe recipe,
  double pixelRatio,
) {
  final lens = recipe.kind == 3;
  values[60] = lens ? recipe.chromaticBand : 0;
  values[46 + superellipseUniformCount + 7] = lens
      ? recipe.chromaticSplit * pixelRatio * recipe.presence
      : 0;
}

@internal
PrismOptics resolveSurfaceOptics(
  PrismOptics packet, {
  required double cornerRadius,
  PrismOptics? widgetOptics,
  double? widgetBlur,
  double? themeBlur,
  double? themeRefraction,
}) => packet.copyWith(
  cornerRadius: cornerRadius,
  frost: widgetBlur ?? (widgetOptics != null ? widgetOptics.frost : themeBlur),
  refraction: widgetOptics != null ? null : themeRefraction,
);

/// Number of scalar uniforms in the surface shader packet.
@visibleForTesting
const int glassUniformCount = 46 + superellipseUniformCount + 16 + 4 + 4 + 1;

@internal
List<FrostPass> resolveSurfaceFrost(
  PrismRecipe recipe,
  double frost, {
  required double tint,
  required bool followsTint,
  double fillFrost = PrismRecipe.blurFillFrost,
}) => FrostPass.resolve(
  kind: recipe.kind,
  dark: recipe.dark,
  frost: frost,
  fillFrost: fillFrost,
  tint: followsTint ? tint : null,
);

@internal
double frostReachOf(List<FrostPass> passes) =>
    passes.fold(0, (reach, pass) => math.max(reach, pass.sigma));

/// Writes the lens underlay extent into the surface shader packet.
@visibleForTesting
void writeLensUnderlayUniform(
  List<double> values,
  PrismRecipe recipe,
  Rect rect,
) {
  values[61] = recipe.kind == 3
      ? math.min(recipe.underlay, math.min(rect.width, rect.height) * 0.55)
      : 0;
}

@internal
class PrismExteriorShadow extends CustomPainter {
  const new(
    this.shape, {
    required this.strength,
    required this.nativeControl,
    this.hdrSurface = false,
  });
  final PrismShape shape;
  final double strength;
  final bool nativeControl;
  final bool hdrSurface;

  static double _sigma(
    PrismShape shape,
    Size size,
    bool nativeControl,
    bool hdrSurface,
  ) => nativeControl
      ? NativeGlassShadow.control.radius * (2 / 3)
      : hdrSurface
      ? NativeGlassShadow.resolve(
              shape.rect(size).shortestSide,
              dark: false,
            ).radius *
            (2 / 3)
      : math.min(shape.rect(size).shortestSide * 0.1, 20);
  static double _drop(
    PrismShape shape,
    Size size,
    bool nativeControl,
    bool hdrSurface,
  ) => nativeControl || hdrSurface
      ? NativeGlassShadow.offset - (hdrSurface ? 1 / 3 : 0)
      : math.min(shape.rect(size).shortestSide * 0.1, 9);

  static double extent(
    PrismShape shape,
    Size size, {
    required bool nativeControl,
    bool hdrSurface = false,
  }) => math.max(
    48,
    _drop(shape, size, nativeControl, hdrSurface) +
        _sigma(shape, size, nativeControl, hdrSurface) * 3,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final rect = Offset.zero & size;
    final outline = shape.path(size);
    final extent = shape.rect(size).shortestSide;
    final sigma = _sigma(shape, size, nativeControl, hdrSurface);
    final drop = _drop(shape, size, nativeControl, hdrSurface);
    final opacity = nativeControl
        ? NativeGlassShadow.control.opacity * NativeGlassShadow.colorAlpha
        : hdrSurface
        ? NativeGlassShadow.resolve(extent, dark: false).opacity *
              NativeGlassShadow.colorAlpha
        : math.min(0.123 * math.pow(extent / 160, 2), 0.14);
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(
            rect.inflate(
              PrismExteriorShadow.extent(
                shape,
                size,
                nativeControl: nativeControl,
                hdrSurface: hdrSurface,
              ),
            ),
          )
          ..addPath(outline, Offset.zero),
      );
    if (opacity > 0.002) {
      _drawOutline(
        canvas,
        rect,
        Offset(0, drop),
        Paint()
          ..color = Color.from(
            alpha: opacity * strength,
            red: 0,
            green: 0,
            blue: 0,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }
    if (!nativeControl && !hdrSurface) {
      _drawOutline(
        canvas,
        rect,
        const Offset(0, 1),
        Paint()
          ..color = const Color(0x06000000)
              .withValues(alpha: (6 / 255) * strength)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      _drawOutline(
        canvas,
        rect,
        const Offset(0, 3),
        Paint()
          ..color = const Color(0x05000000)
              .withValues(alpha: (5 / 255) * strength)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.restore();
  }

  void _drawOutline(Canvas canvas, Rect rect, Offset shift, Paint paint) {
    final bounds = shape.rect(rect.size).shift(shift);
    if (shape.isSmooth && shape.radius > 0) {
      canvas.drawRSuperellipse(
        BorderRadius.circular(shape.effectiveRadius(rect.size))
            .toRSuperellipse(bounds),
        paint,
      );
    } else if (shape.isSmooth) {
      canvas.drawRect(bounds, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bounds,
          Radius.circular(shape.radius),
        ).scaleRadii(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(PrismExteriorShadow oldDelegate) =>
      shape != oldDelegate.shape ||
      strength != oldDelegate.strength ||
      nativeControl != oldDelegate.nativeControl ||
      hdrSurface != oldDelegate.hdrSurface;
}

@internal
class PrismSurfaceRenderWidget extends SingleChildRenderObjectWidget {
  const new({
    super.key,
    required this.shader,
    required this.style,
    required this.shape,
    required this.recipe,
    required this.frost,
    required this.bleed,
    required this.sizedLens,
    required this.press,
    required this.scale,
    required this.group,
    required this.pixelRatio,
    super.child,
  });
  final ui.FragmentShader shader;
  final PrismOptics style;
  final PrismShape shape;
  final PrismRecipe recipe;
  final List<FrostPass> frost;
  final double bleed;
  final bool sizedLens;
  final double press;
  final double scale;
  final PrismGroupData? group;
  final double pixelRatio;
  @override
  RenderPrismSurface createRenderObject(BuildContext context) =>
      RenderPrismSurface(
        shader,
        style,
        shape,
        recipe,
        frost,
        bleed,
        sizedLens,
        press,
        scale,
        pixelRatio,
        group,
      );
  @override
  void updateRenderObject(
    BuildContext context,
    RenderPrismSurface renderObject,
  ) {
    renderObject
      ..shader = shader
      ..style = style
      ..shape = shape
      ..recipe = recipe
      ..hdrShadow = isHDRSurface(recipe)
      ..frost = frost
      ..bleed = bleed
      ..sizedLens = sizedLens
      ..press = press
      ..scale = scale
      ..group = group
      ..pixelRatio = pixelRatio;
  }
}

@internal
class RenderPrismSurface extends RenderProxyBox {
  new(
    this.shader,
    this.style,
    this._shape,
    this._recipe,
    this._frost,
    this._bleed,
    this.sizedLens,
    this.press,
    this._scale,
    this.pixelRatio,
    this._group,
  ) {
    _hdrShadow = isHDRSurface(_recipe);
  }
  bool _hdrShadow = false;
  bool get hdrShadow => _hdrShadow;
  set hdrShadow(bool value) {
    if (_hdrShadow == value) return;
    _hdrShadow = value;
    markNeedsPaint();
  }

  ui.FragmentShader shader;
  PrismOptics style;
  PrismRecipe _recipe;
  PrismRecipe get recipe => _recipe;
  set recipe(PrismRecipe value) {
    final shadowChanged =
        value.kind != _recipe.kind ||
        value.role != _recipe.role ||
        value.shadow != _recipe.shadow ||
        value.presence != _recipe.presence;
    _recipe = value;
    if (shadowChanged) markNeedsPaint();
  }

  List<FrostPass> _frost;
  List<FrostPass> get frost => _frost;
  set frost(List<FrostPass> value) {
    if (listEquals(value, _frost)) return;
    final layers = (blurPass != null, fillSigma != null);
    _frost = value;
    if (layers != (blurPass != null, fillSigma != null)) markNeedsPaint();
  }

  double get frostReach => math.max(style.frost, frostReachOf(_frost));

  bool get plainFrost =>
      (_frost.isEmpty || (_frost.length == 1 && _frost.single.covers)) &&
      bleedOpacity <= 0;

  double get _depthExtent => hasSize ? shape.rect(size).shortestSide : 0;

  double? get fillSigma {
    for (final pass in _frost) {
      if (pass.fill) return pass.sigma;
    }
    return null;
  }

  List<double> get fillUniforms {
    final sigma = fillSigma;
    if (sigma == null) return const [0, 0, 0, -1];
    var directional = 0.0;
    var normal = 0.0;
    for (final pass in _frost) {
      if (!pass.fill) continue;
      if (pass.blendMode == BlendMode.srcOver) {
        normal = pass.opacity;
      } else {
        directional = pass.opacity;
      }
    }
    return [
      directional,
      normal,
      bleedOpacity,
      NativeGlassDepth.bleedRadius(_depthExtent, sigma),
    ];
  }

  FrostPass? get blurPass {
    for (final pass in _frost) {
      if (pass.fill) continue;
      if (!pass.depthFade) return pass;
      final sigma =
          pass.sigma * NativeGlassDepth.amount(_depthExtent) * _baseTaper;
      return sigma >= .5 ? FrostPass(sigma) : null;
    }
    return null;
  }

  static const double _baseTaper = .8;

  bool onScreen(Layer layer) {
    final root = owner?.rootNode;
    if (!attached || !hasSize || root is! RenderView) return true;
    final bounds = MatrixUtils.transformRect(
      compositedTransform(layer),
      (_paintOffset & size).inflate(48),
    );
    return bounds.overlaps(root.paintBounds);
  }

  bool sizedLens;
  double get _lens => sizedLens ? NativeGlassDepth.lens(_depthExtent) : 1;

  double _bleed;
  double get bleed => _bleed;
  set bleed(double value) {
    if (value == _bleed) return;
    _bleed = value;
    markNeedsPaint();
  }

  double get bleedOpacity =>
      _bleed *
      NativeGlassDepth.bleedBlend *
      NativeGlassDepth.amount(_depthExtent);

  PrismShape _shape;
  PrismShape get shape => _shape;
  set shape(PrismShape value) {
    if (value == _shape) return;
    _shape = value;
    markNeedsPaint();
  }

  double press;

  double _scale;
  double get scale => _scale;
  set scale(double value) {
    if (value == _scale) return;
    _scale = value;
    markNeedsPaint();
  }

  Matrix4? get _scaleTransform {
    if (_scale == 1) return null;
    final center = size.center(Offset.zero);
    return Matrix4.translationValues(center.dx, center.dy, 0)
      ..scaleByDouble(_scale, _scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }

  Matrix4 glassTransform([Matrix4? globalTransform]) {
    final transform = globalTransform ?? getTransformTo(null);
    final local = _scaleTransform;
    return local == null ? transform : transform.multiplied(local);
  }

  double pixelRatio;
  PrismGroupData? _group;
  PrismGroupData? get group => _group;
  set group(PrismGroupData? value) {
    if (value == _group) return;
    if (attached) _group?.members.remove(this);
    _group = value;
    if (attached) _group?.members.add(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _group?.members.add(this);
  }

  final _shadowLayer = LayerHandle<PrismSurfaceShadowLayer>();
  final _glassLayer = LayerHandle<PrismSurfaceLayer>();
  final _filterLayer = LayerHandle<BackdropFilterLayer>();
  final _clipLayer = LayerHandle<ClipRectLayer>();
  final _contentLayer = LayerHandle<PrismSurfaceContentLayer>();
  final _contentTransform = LayerHandle<TransformLayer>();
  final _frostClip = LayerHandle<ClipPathLayer>();
  final _frostLayer = LayerHandle<PrismFrostLayer>();
  ClipRectLayer? get clipLayer => _clipLayer.layer;
  PrismFrostLayer? get frostLayer => _frostLayer.layer;
  PrismSurfaceShadowLayer? get shadowLayer => _shadowLayer.layer;
  Offset get paintOffset => _paintOffset;

  @override
  bool get alwaysNeedsCompositing => true;
  Size? _contourSize;
  PrismShape? _contourShape;
  List<double> _contour = List.filled(superellipseUniformCount, 0);
  List<double> uniforms([Matrix4? globalTransform]) {
    if (size != _contourSize || shape != _contourShape) {
      _contourSize = size;
      _contourShape = shape;
      _contour = shape.isSmooth
          ? superellipseUniforms(size, shape.radius)
          : List.filled(superellipseUniformCount, 0);
    }
    final transform = glassTransform(globalTransform);
    final m = transform.storage;
    final rect = shape.rect(size);
    final origin = MatrixUtils.transformPoint(transform, rect.topLeft);
    final values = <double>[
      0,
      0,
      origin.dx * pixelRatio,
      origin.dy * pixelRatio,
      rect.width,
      rect.height,
      m[0],
      m[4],
      m[1],
      m[5],
      style.edgeWidth,
      style.refraction * _lens,
      style.frost,
      style.dispersion * _lens,
      style.tint.r,
      style.tint.g,
      style.tint.b,
      style.tint.a,
      style.saturation,
      style.light,
      style.reflection,
      style.splay,
      style.cornerRadius,
      pixelRatio,
      style.reflectionReach,
      style.brightness,
      ...recipe.uniforms,
      ..._contour,
      ..._derivedUniforms(rect, m),
      ...recipe.faceUniformsFor(rect.shortestSide),
      ...fillUniforms,
      PrismDisplay.headroom.value,
    ];
    assert(
      values.length == glassUniformCount,
      'surface uniform count must match the shader ABI',
    );
    writeChromaticFringeUniforms(values, recipe, pixelRatio);
    writeLensUnderlayUniform(values, recipe, rect);
    values[42] = press;
    values[43] = shape.isSmooth && shape.radius > .001 ? 1 : 0;
    return values;
  }

  List<double> _derivedUniforms(Rect rect, List<double> m) {
    final minExtent = math.min(rect.width, rect.height);
    final edge = math.min(style.edgeWidth, minExtent * 0.49);
    final lens = _lens;
    final displacement = math.min(style.refraction * lens, minExtent * 0.55);
    final dpr = pixelRatio;
    final sigma = style.frost * dpr;

    final rimWidth = math.max(math.min<double>(4, minExtent * 0.25), 0.001);
    var rimEnd = 0.0;
    if (style.reflection > 0.001 && style.reflectionReach > 0.001) {
      final invisible = 0.00784 / math.max(style.reflection, 0.0001);
      rimEnd =
          rimWidth * (1 - math.pow(math.min(invisible, 1), 2 / 3).toDouble());
    }
    final radius = math.min(style.cornerRadius, minExtent * 0.5);

    final det = (m[0] * m[5] - m[4] * m[1]).abs();
    final pixel = 1 / (dpr * math.sqrt(math.max(det, 1e-8)));
    final bypass =
        math.max<double>(
          math.max(math.max<double>(24, 2.5 * pixel), edge),
          recipe.kind == 3 ? recipe.chromaticBand : 0,
        ) +
        0.5 +
        0.02 * radius;
    return [
      1 / math.max(edge, 0.001),
      displacement,
      style.dispersion * lens * (2 + displacement * 0.12) * dpr,
      0.2025 * style.frost * style.frost * dpr * dpr,
      sigma,
      math.max(2.25, 0.09 * sigma * sigma),

      4.84 * sigma * sigma,
      0,
      rimWidth,
      rimEnd,
      style.frost * 0.85,
      radius,
      rimEnd,
      1 / dpr,
      rect.width / rect.height,
      bypass,
    ];
  }

  Offset _paintOffset = Offset.zero;

  static bool _debugReportedRasterTransform = false;

  void _debugCheckRasterTransform(Layer layer) {
    if (_debugReportedRasterTransform || !attached || !hasSize) return;
    if (!transformedAfterRaster(
      composited: compositedTransform(layer),
      paintOffset: _paintOffset,
      global: getTransformTo(null),
      pixelRatio: pixelRatio,
      bounds: Offset.zero & size,
    )) {
      return;
    }
    _debugReportedRasterTransform = true;
    debugPrint(
      'RawPrismSurface: an ancestor moves this glass after rasterization, so '
      'its refraction and rim are drawn away from its content. '
      'Transform(filterQuality: ...) and other ImageFilter.matrix layers do '
      'this. Remove filterQuality from the ancestor Transform; a plain '
      'transform keeps glass aligned. See doc/rendering.md.',
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    _paintOffset = offset;
    final shadow = _shadowLayer.layer ??= PrismSurfaceShadowLayer(this);
    context.pushLayer(shadow, (context, offset) {
      final canvas = context.canvas
        ..save()
        ..translate(offset.dx, offset.dy);
      final local = _scaleTransform;
      if (local != null) canvas.transform(local.storage);
      PrismExteriorShadow(
        shape,
        strength: recipe.shadowStrength,
        nativeControl: recipe.usesNativeControlShadow,
        hdrSurface: hdrShadow,
      ).paint(canvas, size);
      canvas.restore();
    }, offset);

    final blur = blurPass != null;
    final fill = fillSigma != null;
    if (blur || fill) {
      final frost = (_frostLayer.layer ??= PrismFrostLayer())..glass = this;
      final local = _scaleTransform;
      final contour = local == null
          ? shape.path(size)
          : shape.path(size).transform(local.storage);
      final bounds = contour.getBounds();
      _frostClip.layer = context.pushClipPath(
        needsCompositing,
        offset,
        bounds,
        contour,
        (context, offset) => context.pushLayer(frost, (context, offset) {
          frost.bounds = bounds.shift(offset);
          if (blur) context.pushLayer(frost.blur, (_, _) {}, offset);
        }, offset),
        oldLayer: _frostClip.layer,
      );
    } else {
      _frostClip.layer = null;
    }
    final layer = (_glassLayer.layer ??= PrismSurfaceLayer())
      ..glass = this
      ..filter = _filterLayer.layer ??= BackdropFilterLayer();
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      MatrixUtils.transformRect(
        _scaleTransform ?? Matrix4.identity(),
        Offset.zero & size,
      ).inflate(2),
      (context, offset) => context.pushLayer(
        layer,
        (context, offset) =>
            context.pushLayer(layer.filter!, (context, offset) {}, offset),
        offset,
      ),
      oldLayer: _clipLayer.layer,
    );
    final content = _contentLayer.layer ??= PrismSurfaceContentLayer();
    context.pushLayer(content, (context, offset) {
      final local = _scaleTransform;
      if (local == null) {
        _contentTransform.layer = null;
        super.paint(context, offset);
      } else {
        _contentTransform.layer = context.pushTransform(
          needsCompositing,
          offset,
          local,
          super.paint,
          oldLayer: _contentTransform.layer,
        );
      }
    }, offset);
  }

  @override
  void detach() {
    _group?.members.remove(this);
    _glassLayer.layer?.glass = null;
    _frostLayer.layer?.glass = null;
    super.detach();
  }

  @override
  void dispose() {
    _glassLayer.layer?.glass = null;
    _frostLayer.layer?.glass = null;
    _frostClip.layer = null;
    _frostLayer.layer = null;
    _shadowLayer.layer = null;
    _glassLayer.layer = null;
    _filterLayer.layer = null;
    _clipLayer.layer = null;
    _contentLayer.layer = null;
    _contentTransform.layer = null;
    super.dispose();
  }
}

@internal
class PrismSurfaceLayer extends ContainerLayer {
  RenderPrismSurface? glass;
  BackdropFilterLayer? filter;
  final _filterCache = PrismFilterCache();
  @override
  bool get alwaysNeedsAddToScene => true;
  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = glass;
    if (owner == null || !owner.attached) return;
    assert(() {
      owner._debugCheckRasterTransform(this);
      return true;
    }(), 'raster transform diagnostics must complete');
    final group = owner._group;
    if (group == null && !owner.onScreen(this)) return;
    final batch = group?.prepared[owner];
    final backdrop = filter!;
    if (batch == null) {
      backdrop
        ..backdropKey = group != null && group.shared.contains(owner)
            ? group.sharedKey
            : null
        ..filter = _filterCache.resolve(owner.shader, owner.uniforms(), 0);
    } else {
      backdrop
        ..backdropKey = batch.key
        ..filter = batch.filter;
    }
    backdrop.markNeedsAddToScene();
    addChildrenToScene(builder);
  }
}

@internal
class PrismSurfaceContentLayer extends ContainerLayer;

@internal
class PrismFrostLayer extends ContainerLayer {
  RenderPrismSurface? glass;

  final _blur = LayerHandle<BackdropFilterLayer>();
  final _fills = [
    LayerHandle<BackdropFilterLayer>(),
    LayerHandle<BackdropFilterLayer>(),
  ];
  FrostPass? _blurred;

  BackdropFilterLayer get blur => _blur.layer ??= BackdropFilterLayer();
  BackdropFilterLayer fill(int half) =>
      _fills[half].layer ??= BackdropFilterLayer();

  Rect bounds = Rect.zero;

  void addFill(ui.SceneBuilder builder, Rect bounds) {
    final outer = bounds.inflate(1);
    final middle = outer.center.dx;
    for (var i = 0; i < 2; i++) {
      builder.pushClipRect(
        i == 0
            ? Rect.fromLTRB(outer.left, outer.top, middle, outer.bottom)
            : Rect.fromLTRB(middle, outer.top, outer.right, outer.bottom),
      );
      fill(i).addToScene(builder);
      builder.pop();
    }
  }

  void configureBlur(FrostPass pass, [BackdropKey? key]) {
    if (pass != _blurred) {
      _blurred = pass;
      blur.filter = ui.ImageFilter.blur(
        sigmaX: pass.sigma,
        sigmaY: pass.sigma,
        tileMode: ui.TileMode.clamp,
      );
    }
    blur
      ..backdropKey = key
      ..markNeedsAddToScene();
  }

  void configureFill(double sigma, BackdropKey key) {
    final filter = PrismShaderCache.fillFilter(sigma);
    for (var i = 0; i < 2; i++) {
      fill(i)
        ..filter = filter
        ..blendMode = BlendMode.modulate
        ..backdropKey = key
        ..markNeedsAddToScene();
    }
  }

  @override
  void dispose() {
    _blur.layer = null;
    for (var i = 0; i < 2; i++) {
      _fills[i].layer = null;
    }
    super.dispose();
  }

  @override
  bool get alwaysNeedsAddToScene => true;
  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = glass;
    if (owner == null || !owner.attached) return;
    final group = owner._group;
    if (group != null &&
        (group.prepared[owner] != null || group.shared.contains(owner))) {
      return;
    }
    if (!owner.onScreen(this)) return;
    final pass = owner.blurPass;
    if (pass != null) configureBlur(pass);
    final sigma = owner.fillSigma;
    if (sigma != null) {
      configureFill(sigma, PrismFillShare.keyFor(owner, this, sigma));
    }
    addChildrenToScene(builder);
    if (sigma != null) addFill(builder, bounds);
  }
}

/// Whether two layers share a clear backdrop, or null if disconnected.
@visibleForTesting
bool? sameBackdropBetween(Layer from, Layer to) =>
    PrismFillShare._clearBetween(from, to);

@internal
abstract final class PrismFillShare {
  static final _keys = <BackdropKey>[];
  static int _index = 0;
  static double? _sigma;

  static Layer? _last;
  static final _glass = <Rect>[];

  static BackdropKey keyFor(
    RenderPrismSurface glass,
    Layer at,
    double sigma, {
    bool join = false,
  }) {
    final last = _last;
    final clear = last == null
        ? null
        : join
        ? sigma == _sigma
        : _clearBetween(last, at);
    _last = at;
    if (clear == null) {
      _index = 0;
      _glass.clear();
    } else if (!clear ||
        sigma != _sigma ||
        _glass.any(_rectOf(glass).overlaps)) {
      _index++;
      _glass.clear();
    }
    _sigma = sigma;
    while (_keys.length <= _index) {
      _keys.add(BackdropKey());
    }
    return _keys[_index];
  }

  static Rect _rectOf(RenderPrismSurface glass) => MatrixUtils.transformRect(
    glass.glassTransform(),
    Offset.zero & glass.size,
  );

  static bool? _clearBetween(Layer from, Layer to) {
    final ancestors = <Layer>{};
    for (Layer? layer = to.parent; layer != null; layer = layer.parent) {
      ancestors.add(layer);
    }
    var clear = true;
    var descend = false;
    Layer? layer = from;
    while (true) {
      Layer? next;
      if (descend && layer is ContainerLayer) next = layer.firstChild;
      for (var up = layer; next == null && up != null; up = up.parent) {
        next = up.nextSibling;

        if (next == null && up.parent != null && !_transparent(up.parent!)) {
          clear = false;
        }
      }
      if (next == null) return null;
      if (identical(next, to)) return clear;
      layer = next;
      if (layer is PrismSurfaceLayer ||
          layer is PrismSurfaceShadowLayer ||
          layer is PrismFrostLayer ||
          layer is PrismSurfaceContentLayer) {
        final owner = layer is PrismSurfaceLayer ? layer.glass : null;
        if (owner != null && owner.attached && owner.hasSize) {
          _glass.add(_rectOf(owner));
        }

        descend = ancestors.contains(layer);
        if (descend) clear = false;
      } else {
        descend = true;
        if (!_transparent(layer)) clear = false;
      }
    }
  }

  static bool _transparent(Layer layer) => switch (layer) {
    ClipRectLayer(:final clipBehavior) ||
    ClipRRectLayer(:final clipBehavior) ||
    ClipRSuperellipseLayer(:final clipBehavior) ||
    ClipPathLayer(
      :final clipBehavior,
    ) => clipBehavior != Clip.antiAliasWithSaveLayer,
    AnnotatedRegionLayer() ||
    LeaderLayer() ||
    FollowerLayer() ||
    PrismGroupLayer() => true,
    _ => const {
      ContainerLayer,
      OffsetLayer,
      TransformLayer,
    }.contains(layer.runtimeType),
  };
}

@internal
class PrismFilterCache {
  ui.FragmentShader? _shader;
  List<double>? _values;
  double? _frost;
  late ui.ImageFilter _filter;

  ui.ImageFilter resolve(
    ui.FragmentShader shader,
    List<double> values,
    double frost,
  ) {
    if (!identical(shader, _shader) ||
        frost != _frost ||
        !listEquals(values, _values)) {
      for (var i = 2; i < values.length; i++) {
        shader.setFloat(i, values[i]);
      }
      _filter = _opticalFilter(shader, frost);
      _shader = shader;
      _values = values;
      _frost = frost;
    }
    return _filter;
  }
}

ui.ImageFilter _opticalFilter(ui.FragmentShader shader, double frost) =>
    frost > 0.05
    ? ui.ImageFilter.compose(
        outer: ui.ImageFilter.shader(
          shader,
          filterQuality: ui.FilterQuality.low,
        ),
        inner: ui.ImageFilter.blur(
          sigmaX: frost,
          sigmaY: frost,
          tileMode: ui.TileMode.clamp,
        ),
      )
    : ui.ImageFilter.shader(shader, filterQuality: ui.FilterQuality.low);

@internal
class PrismSurfaceShadowLayer extends ContainerLayer {
  new(this.glass);
  final RenderPrismSurface glass;
  @override
  bool get alwaysNeedsAddToScene => true;
  @override
  void addToScene(ui.SceneBuilder builder) {
    if (!glass.attached) return;
    final group = glass._group;
    if (group == null) {
      addChildrenToScene(builder);
      return;
    }
    if (group.prepared.containsKey(glass)) return;
    if (!group.shared.contains(glass)) {
      addChildrenToScene(builder);
      return;
    }
    if (group.hoistHost == null) {
      group
        ..hoistHost = glass
        ..hoist(builder, glass, glass._paintOffset);
    }
  }
}
