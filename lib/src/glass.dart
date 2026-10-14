import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'style.dart';
import 'superellipse.dart';
import 'material.dart';
import 'edge_fade.dart';
import 'glass_transition.dart';
import 'layer_transform.dart';
import 'theme.dart';
import 'recipe.dart';
import 'pressable.dart';

part 'edge_blur.dart';
part 'glass_group.dart';

/// A live backdrop lens. Foreground content stays sharp above the material.
///
/// Call [preload] before runApp to compile the program before the first lens.
/// Refraction uses Flutter shader filters on Impeller; unsupported renderers
/// use a frosted fallback.
/// Ancestor ImageFiltered/Opacity saveLayers isolate the backdrop and are
/// outside the supported composition, as is an ancestor
/// `Transform(filterQuality: ...)`, which scales the glass only after its
/// backdrop is rasterized. A plain ancestor transform is supported.
class LiquidPrism extends StatefulWidget {
  const LiquidPrism({
    super.key,
    this.glass,
    this.blur,
    this.optics,
    this.shape,
    this.child,
    this.role = GlassRole.surface,
    this.lensRim = 0,
    this.chromaticSplit = 0,
    this.chromaticBand = 0,
  }) : assert(blur == null || (blur >= 0 && blur <= 12)),
       assert(lensRim >= 0),
       assert(chromaticSplit >= 0),
       assert(chromaticBand >= 0);
  final Glass? glass;
  final double? blur;

  /// Expert optics override the material recipe. Shape and fluent tint still apply.
  final LiquidPrismStyle? optics;

  /// Defaults to capsule, or the advanced style's corner radius when provided.
  final GlassShape? shape;
  @internal
  final GlassRole role;

  /// The selected tab pill's bright glint; only the lifted lens
  /// recipe reads it.
  @internal
  final double lensRim;

  /// Effective lifted-lens red–blue split and band depth, in points.
  @internal
  final double chromaticSplit;
  @internal
  final double chromaticBand;
  final Widget? child;
  static ui.FragmentProgram? _program;
  static ui.FragmentProgram? _batchProgram;
  static ui.FragmentProgram? _edgeProgram;
  static ui.FragmentProgram? _hazeProgram;
  static ui.Image? _linearSampler;
  static Future<void>? _loading;

  /// Whether the current renderer supports custom backdrop shaders.
  static bool get isShaderSupported => ui.ImageFilter.isShaderFilterSupported;
  static Future<void> preload() async {
    if (_loading != null) return _loading!;
    if (!isShaderSupported || (_program != null && _linearSampler != null)) {
      return;
    }
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const Color(0xFFFFFFFF), BlendMode.src);
      final picture = recorder.endRecording();
      try {
        _linearSampler ??= await picture.toImage(1, 1);
      } finally {
        picture.dispose();
      }
      _program = await ui.FragmentProgram.fromAsset(
        'packages/liquid_prism/shaders/glass.frag',
      );
      try {
        _batchProgram = await ui.FragmentProgram.fromAsset(
          'packages/liquid_prism/shaders/glass_batch.frag',
        );
      } catch (error) {
        // Batching is optional. The scalar optical filter remains available.
        debugPrint('LiquidPrism: shared optical pass unavailable: $error');
      }
      try {
        _edgeProgram ??= await ui.FragmentProgram.fromAsset(
          'packages/liquid_prism/shaders/edge_blur.frag',
        );
        _hazeProgram ??= await ui.FragmentProgram.fromAsset(
          'packages/liquid_prism/shaders/edge_haze.frag',
        );
      } catch (error) {
        // Edge blurs are optional; their fades still paint.
        debugPrint('LiquidPrism: edge blur unavailable: $error');
      }
    } finally {
      _loading = null;
    }
  }

  static ui.FragmentShader? _createShader() {
    final shader = _program?.fragmentShader();
    if (shader != null) {
      shader.setImageSampler(
        0,
        _linearSampler!,
        filterQuality: ui.FilterQuality.low,
      );
    }
    return shader;
  }

  /// The edge blur reads pairs of texels through one bilinear sample, so its
  /// backdrop sampler is bound linear the same way.
  static ui.FragmentShader? _createEdgeShader() {
    final shader = _edgeProgram?.fragmentShader();
    if (shader != null && _linearSampler != null) {
      shader.setImageSampler(
        0,
        _linearSampler!,
        filterQuality: ui.FilterQuality.low,
      );
    }
    return shader;
  }

  static ui.FragmentShader? _createHazeShader() {
    final shader = _hazeProgram?.fragmentShader();
    if (shader != null && _linearSampler != null) {
      shader.setImageSampler(
        0,
        _linearSampler!,
        filterQuality: ui.FilterQuality.low,
      );
    }
    return shader;
  }

  @override
  State<LiquidPrism> createState() => _LiquidPrismState();
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<LiquidPrismStyle>('optics', optics))
      ..add(DiagnosticsProperty<Glass>('glass', glass))
      ..add(DoubleProperty('blur', blur))
      ..add(DiagnosticsProperty<GlassShape>('shape', shape));
  }
}

class _LiquidPrismState extends State<LiquidPrism> {
  Glass get _material => widget.glass ?? _theme.glass ?? Glass.regular;
  LiquidPrismThemeData _theme = const LiquidPrismThemeData();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = LiquidPrismTheme.of(context);
    _ensureShader();
  }

  ui.FragmentShader? _shader;
  @override
  void didUpdateWidget(LiquidPrism oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureShader();
  }

  bool _loadingShader = false;
  void _ensureShader() {
    if (_material.variant == GlassVariant.identity ||
        _material.isInteractive ||
        _shader != null ||
        _loadingShader) {
      return;
    }
    if (LiquidPrism._program != null) {
      _shader = LiquidPrism._createShader();
    } else if (LiquidPrism.isShaderSupported) {
      _load();
    }
  }

  Future<void> _load() async {
    _loadingShader = true;
    try {
      await LiquidPrism.preload();
      if (mounted &&
          _material.variant != GlassVariant.identity &&
          !_material.isInteractive) {
        setState(() {
          _shader = LiquidPrism._createShader();
        });
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'liquid_prism',
          context: ErrorDescription('while compiling the glass shader'),
        ),
      );
    } finally {
      _loadingShader = false;
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_material.variant == GlassVariant.identity) {
      return widget.child ?? const SizedBox.shrink();
    }
    if (_material.isInteractive) {
      return LiquidPrismPressable.feedback(
        child: LiquidPrism(
          glass: _material.interactive(false),
          optics: widget.optics,
          shape: widget.shape,
          blur: widget.blur,
          role: widget.role,
          lensRim: widget.lensRim,
          chromaticSplit: widget.chromaticSplit,
          chromaticBand: widget.chromaticBand,
          child: widget.child,
        ),
      );
    }
    final theme = _theme;
    final optics = widget.optics ?? theme.optics;
    final shape =
        widget.shape ??
        (widget.optics == null
            ? null
            : GlassShape.rect(cornerRadius: widget.optics!.cornerRadius)) ??
        theme.shape ??
        (optics == null
            ? GlassShape.capsule
            : GlassShape.rect(cornerRadius: optics.cornerRadius));
    // Presence fades the optical output and shadows through the recipe and
    // grows the lens and frost from zero, so the backdrop stays live.
    final presenceScope = LiquidPrismPresence.maybeData(context);
    final presence = presenceScope == null
        ? 1.0
        : presenceScope.progress.value.clamp(0.0, 1.0);
    final materialize = presenceScope?.materialize ?? false;
    final recipe =
        GlassRecipe.resolve(
              _material,
              LiquidPrismTheme.materialBrightnessOf(context),
              widget.role,
              customOptics: optics != null,
            )
            .withPresence(presence)
            .withLensRim(widget.lensRim)
            .withChromaticFringe(widget.chromaticSplit, widget.chromaticBand);
    var style = (optics ?? recipe.optics(shape.radius)).copyWith(
      cornerRadius: shape.radius,
      frost:
          widget.blur ??
          (widget.optics != null ? widget.optics!.frost : theme.blur),
    );
    if (presence < 1) {
      // Frost is its own backdrop pass, which the output fade cannot reach,
      // so it always follows presence. Materializing also grows the lens on
      // the same curve, so the outline never arrives ahead of it; a plain
      // fade keeps the full lens. The spring supplies the easing.
      style = style.copyWith(
        frost: style.frost * presence,
        refraction: materialize ? style.refraction * presence : null,
        dispersion: materialize ? style.dispersion * presence : null,
      );
    }
    final shader = _shader;
    final press = LiquidPrismPressFeedback.of(context);
    final pressScale = LiquidPrismPressFeedback.scaleOf(context);
    // Nested glass inherits the press highlight but not the scale, which this
    // surface already applies to its content.
    // Content fades and sharpens with the material. The wrappers stay in the
    // tree at full presence (no layers) so child state survives.
    final contentBlur = materialize
        ? (1 - presence) * presenceScope!.contentBlur
        : 0.0;
    final content = LiquidPrismPressFeedback(
      progress: press,
      child: Opacity(
        opacity: presence,
        child: ImageFiltered(
          enabled: contentBlur > .05,
          imageFilter: ui.ImageFilter.blur(
            sigmaX: contentBlur,
            sigmaY: contentBlur,
            tileMode: ui.TileMode.decal,
          ),
          child: widget.child ?? const SizedBox.shrink(),
        ),
      ),
    );
    final fallbackTint = Color.alphaBlend(
      _material.tintColor ?? const Color(0x00000000),
      optics?.tint ?? Color(recipe.dark ? 0x99000000 : 0x99FFFFFF),
    );
    final glass = CustomPaint(
      painter: shader == null
          ? _ExteriorShadow(
              shape,
              strength: recipe.shadowStrength,
              nativeControl: recipe.usesNativeControlShadow,
            )
          : null,
      child: shader != null
          ? _GlassRenderWidget(
              shader: shader,
              style: style,
              shape: shape,
              recipe: recipe,
              press: press,
              scale: pressScale,
              group: _GlassGroupScope.of(context),
              pixelRatio: MediaQuery.devicePixelRatioOf(context),
              child: ClipPath(
                clipper: GlassShapeClipper(shape),
                child: content,
              ),
            )
          : ClipPath(
              clipper: GlassShapeClipper(shape),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: style.frost + 4,
                  sigmaY: style.frost + 4,
                ),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: Color.alphaBlend(
                      Color.from(
                        alpha: 0.08 * press,
                        red: 1,
                        green: 1,
                        blue: 1,
                      ),
                      fallbackTint,
                    ),
                    shape: shape.isSmooth
                        ? RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(shape.radius),
                            side: const BorderSide(color: Color(0x55FFFFFF)),
                          )
                        : shape.isCircle
                        ? const CircleBorder(
                            side: BorderSide(color: Color(0x55FFFFFF)),
                          )
                        : RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(shape.radius),
                            side: const BorderSide(color: Color(0x55FFFFFF)),
                          ),
                  ),
                  child: content,
                ),
              ),
            ),
    );
    // The fallback blur tolerates a transform; the shader path scales itself.
    // Keep the subtree stable at unity: removing this wrapper would cancel
    // gestures and focus owned by controls inside a shared glass surface.
    return shader == null
        ? Transform.scale(
            scale: pressScale,
            // The frosted fallback has no optical inputs to fade.
            child: Opacity(opacity: recipe.presence, child: glass),
          )
        : glass;
  }
}

/// Writes the reserved scalar slots; regular batch members always carry zero.
/// Split is raster pixels before the sampling transform; depth is local points.
@visibleForTesting
void writeChromaticFringeUniforms(
  List<double> values,
  GlassRecipe recipe,
  double pixelRatio,
) {
  final lens = recipe.kind == 3;
  values[60] = lens ? recipe.chromaticBand : 0; // u_shapeD.z
  values[46 + superellipseUniformCount + 7] = lens
      ? recipe.chromaticSplit * pixelRatio * recipe.presence
      : 0; // u_derived[1].w
}

/// Contact, soft and ambient shadows only darken pixels outside the glass.
class _ExteriorShadow extends CustomPainter {
  const _ExteriorShadow(
    this.shape, {
    required this.strength,
    required this.nativeControl,
  });
  final GlassShape shape;
  final double strength;
  final bool nativeControl;

  static double _sigma(GlassShape shape, Size size, bool nativeControl) =>
      nativeControl
      ? NativeGlassShadow.control.radius * (2 / 3)
      : math.min(shape.rect(size).shortestSide * 0.1, 20.0);
  static double _drop(GlassShape shape, Size size, bool nativeControl) =>
      nativeControl
      ? NativeGlassShadow.offset
      : math.min(shape.rect(size).shortestSide * 0.1, 9.0);

  /// How far outside the contour the shadow paints, in logical pixels.
  static double extent(
    GlassShape shape,
    Size size, {
    required bool nativeControl,
  }) => math.max(
    48,
    _drop(shape, size, nativeControl) + _sigma(shape, size, nativeControl) * 3,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outline = shape.path(size);
    // Geometry sets the shadow profile; mode scales opacity independently of blur.
    final extent = shape.rect(size).shortestSide;
    final sigma = _sigma(shape, size, nativeControl);
    final drop = _drop(shape, size, nativeControl);
    final opacity = nativeControl
        ? NativeGlassShadow.control.opacity * NativeGlassShadow.colorAlpha
        : math.min(0.123 * math.pow(extent / 160, 2), 0.14);
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(
          rect.inflate(
            _ExteriorShadow.extent(shape, size, nativeControl: nativeControl),
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
    if (!nativeControl) {
      _drawOutline(
        canvas,
        rect,
        const Offset(0, 1),
        Paint()
          ..color = Color(0x06000000).withValues(alpha: (6 / 255) * strength)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      _drawOutline(
        canvas,
        rect,
        const Offset(0, 3),
        Paint()
          ..color = Color(0x05000000).withValues(alpha: (5 / 255) * strength)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.restore();
  }

  /// Same contour as [GlassShape.path], drawn as a primitive so Impeller can
  /// use its analytic blurred-shape shader rather than tessellating a path.
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
  bool shouldRepaint(_ExteriorShadow oldDelegate) =>
      shape != oldDelegate.shape ||
      strength != oldDelegate.strength ||
      nativeControl != oldDelegate.nativeControl;
}

class _GlassRenderWidget extends SingleChildRenderObjectWidget {
  const _GlassRenderWidget({
    required this.shader,
    required this.style,
    required this.shape,
    required this.recipe,
    required this.press,
    required this.scale,
    required this.group,
    required this.pixelRatio,
    super.child,
  });
  final ui.FragmentShader shader;
  final LiquidPrismStyle style;
  final GlassShape shape;
  final GlassRecipe recipe;
  final double press;
  final double scale;
  final _GlassGroupData? group;
  final double pixelRatio;
  @override
  _RenderGlass createRenderObject(BuildContext context) => _RenderGlass(
    shader,
    style,
    shape,
    recipe,
    press,
    scale,
    pixelRatio,
    group,
  );
  @override
  void updateRenderObject(BuildContext context, _RenderGlass renderObject) {
    renderObject
      ..shader = shader
      ..style = style
      ..shape = shape
      ..recipe = recipe
      ..press = press
      ..scale = scale
      ..group = group
      ..pixelRatio = pixelRatio;
  }
}

class _RenderGlass extends RenderProxyBox {
  _RenderGlass(
    this.shader,
    this.style,
    this._shape,
    this._recipe,
    this.press,
    this._scale,
    this.pixelRatio,
    this._group,
  );
  // Optical inputs are read as uniforms when the scene is composed, which every
  // frame does for this layer; only the shadow and clip geometry need a repaint.
  ui.FragmentShader shader;
  LiquidPrismStyle style;
  GlassRecipe _recipe;
  GlassRecipe get recipe => _recipe;
  set recipe(GlassRecipe value) {
    // Mode and presence changes affect recorded exterior and inner shadows.
    final shadowChanged =
        value.kind != _recipe.kind ||
        value.role != _recipe.role ||
        value.presence != _recipe.presence;
    _recipe = value;
    if (shadowChanged) markNeedsPaint();
  }

  GlassShape _shape;
  GlassShape get shape => _shape;
  set shape(GlassShape value) {
    if (value == _shape) return;
    _shape = value;
    markNeedsPaint();
  }

  double press;

  /// Press scale about the center. Applied to the contour uniforms, clip,
  /// shadow and content rather than as an ancestor transform: Impeller
  /// re-rasterizes a shader filter's backdrop when its basis is not identity.
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

  /// Screen transform of the glass contour, including the press scale.
  Matrix4 glassTransform([Matrix4? globalTransform]) {
    final transform = globalTransform ?? getTransformTo(null);
    final local = _scaleTransform;
    return local == null ? transform : transform.multiplied(local);
  }

  double pixelRatio;
  _GlassGroupData? _group;
  set group(_GlassGroupData? value) {
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

  final _shadowLayer = LayerHandle<_GlassShadowLayer>();
  final _glassLayer = LayerHandle<_GlassLayer>();
  final _filterLayer = LayerHandle<BackdropFilterLayer>();
  final _clipLayer = LayerHandle<ClipRectLayer>();
  final _contentLayer = LayerHandle<TransformLayer>();
  final _frostClip = LayerHandle<ClipPathLayer>();
  final _frostLayer = LayerHandle<_FrostLayer>();
  @override
  bool get alwaysNeedsCompositing => true;
  Size? _contourSize;
  GlassShape? _contourShape;
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
      0, 0, // The engine supplies the bound texture size.
      origin.dx * pixelRatio, origin.dy * pixelRatio, rect.width, rect.height,
      m[0], m[4], m[1], m[5],
      style.edgeWidth, style.refraction, style.frost, style.dispersion,
      style.tint.r, style.tint.g, style.tint.b, style.tint.a,
      style.saturation, style.light, style.reflection, style.splay,
      style.cornerRadius, pixelRatio, style.reflectionReach, style.brightness,
      ...recipe.uniforms,
      ..._contour,
      ..._derivedUniforms(rect, m),
    ];
    writeChromaticFringeUniforms(values, recipe, pixelRatio);
    values[42] = press;
    values[43] = shape.isSmooth && shape.radius > .001 ? 1 : 0;
    return values;
  }

  /// Uniform-only terms of the optical shader (u_derived), computed once per
  /// surface here instead of once per fragment. The layout is documented in
  /// shaders/glass.frag; every expression mirrors the one the shader evaluated.
  List<double> _derivedUniforms(Rect rect, List<double> m) {
    final minExtent = math.min(rect.width, rect.height);
    final edge = math.min(style.edgeWidth, minExtent * 0.49);
    final displacement = math.min(style.refraction, minExtent * 0.55);
    final dpr = pixelRatio;
    final sigma = style.frost * dpr;
    var broadEnd = 0.0;
    var rimEnd = 0.0;
    if (style.reflection > 0.001 && style.reflectionReach > 0.001) {
      // Where a channel can no longer move by two 8-bit steps.
      final invisible = 0.00784 / math.max(style.reflection, 0.0001);
      broadEnd = 24 * (1 - math.sqrt(math.min(invisible / 0.32, 1)));
      rimEnd = 4 * (1 - math.pow(math.min(invisible, 1), 2 / 3).toDouble());
    }
    final radius = math.min(style.cornerRadius, minExtent * 0.5);
    // One device pixel in points, from the contour transform's scale. The
    // smooth-corner field is bypassed only past the reflections, the lens band
    // and the coverage ramp with its derivative quad, plus the 0.0181 r by
    // which the round-corner depth can exceed the smooth-corner depth.
    final det = (m[0] * m[5] - m[4] * m[1]).abs();
    final pixel = 1 / (dpr * math.sqrt(math.max(det, 1e-8)));
    final bypass =
        math.max(
          math.max(math.max(24.0, 2.5 * pixel), edge),
          recipe.kind == 3 ? recipe.chromaticBand : 0,
        ) +
        0.5 +
        0.02 * radius;
    return [
      1 / math.max(edge, 0.001),
      displacement,
      style.dispersion * (2 + displacement * 0.12) * dpr,
      0.2025 * style.frost * style.frost * dpr * dpr,
      sigma,
      math.max(2.25, 0.09 * sigma * sigma),
      0.49 * sigma * sigma,
      0, // Chromatic split is written alongside its band after packet assembly.
      broadEnd,
      rimEnd,
      style.frost * 0.85,
      radius,
      math.max(broadEnd, rimEnd),
      1 / dpr,
      rect.width / rect.height,
      bypass,
    ];
  }

  /// Where [paint] placed this surface within its enclosing layer.
  Offset _paintOffset = Offset.zero;

  static bool _debugReportedRasterTransform = false;

  /// Reports, once per run, glass whose uniforms cannot match the coordinates
  /// its backdrop is rasterized in. An ancestor `ImageFilter.matrix` layer, as
  /// `Transform(filterQuality: ...)` composites, renders this glass into an
  /// offscreen layer at an origin Impeller chooses and then moves the result,
  /// so the optical pass would draw its contour away from the content.
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
      'LiquidPrism: an ancestor moves this glass after it is rasterized, so '
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
    final shadow = _shadowLayer.layer ??= _GlassShadowLayer(this);
    context.pushLayer(shadow, (context, offset) {
      final canvas = context.canvas;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      final local = _scaleTransform;
      if (local != null) canvas.transform(local.storage);
      _ExteriorShadow(
        shape,
        strength: recipe.shadowStrength,
        nativeControl: recipe.usesNativeControlShadow,
      ).paint(canvas, size);
      canvas.restore();
    }, offset);
    // Frost runs as its own backdrop pass clipped to the contour. Composed under
    // the optical shader it would be rendered without a coverage limit: Impeller
    // blurs the whole captured backdrop for every surface, every frame.
    if (style.frost > 0.05) {
      final frost = _frostLayer.layer ??= _FrostLayer();
      frost.glass = this;
      final local = _scaleTransform;
      final contour = local == null
          ? shape.path(size)
          : shape.path(size).transform(local.storage);
      _frostClip.layer = context.pushClipPath(
        needsCompositing,
        offset,
        contour.getBounds(),
        contour,
        (context, offset) => context.pushLayer(
          frost,
          (context, offset) =>
              context.pushLayer(frost.filter, (_, _) {}, offset),
          offset,
        ),
        oldLayer: _frostClip.layer,
      );
    } else {
      _frostClip.layer = null;
    }
    final layer = _glassLayer.layer ??= _GlassLayer();
    layer.glass = this;
    layer.filter = _filterLayer.layer ??= BackdropFilterLayer();
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
    final local = _scaleTransform;
    if (recipe.kind != 0) {
      final canvas = context.canvas;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      if (local != null) canvas.transform(local.storage);
      canvas.clipPath(shape.path(size));
      canvas.drawPath(
        shape.path(size).shift(const Offset(0, NativeGlassShadow.offset)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = NativeGlassShadow.ringWidth
          ..color = Color.from(
            alpha: NativeGlassShadow.ringOpacity * recipe.shadowStrength,
            red: 0,
            green: 0,
            blue: 0,
          )
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            NativeGlassShadow.ringRadius,
          ),
      );
      canvas.restore();
    }
    if (local == null) {
      _contentLayer.layer = null;
      super.paint(context, offset);
    } else {
      _contentLayer.layer = context.pushTransform(
        needsCompositing,
        offset,
        local,
        super.paint,
        oldLayer: _contentLayer.layer,
      );
    }
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
    super.dispose();
  }
}

/// Uniforms follow retained scroll/transform layers at scene composition time.
class _GlassLayer extends ContainerLayer {
  _RenderGlass? glass;
  BackdropFilterLayer? filter;
  final _filterCache = _GlassFilterCache();
  @override
  bool get alwaysNeedsAddToScene => true;
  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = glass;
    if (owner == null || !owner.attached) return;
    assert(() {
      owner._debugCheckRasterTransform(this);
      return true;
    }());
    final batch = owner._group?.prepared[owner];
    final backdrop = filter!;
    if (batch == null) {
      final group = owner._group;
      // Shared members read one capture: the group paints every shared
      // member's shadow and frost ahead of the first shared optical pass
      // (see _GlassShadowLayer), so a frosted member finds its own frost in
      // the shared capture and no later member's paint reaches its sampling.
      backdrop.backdropKey = group != null && group.shared.contains(owner)
          ? group.sharedKey
          : null;
      backdrop.filter = _filterCache.resolve(
        owner.shader,
        owner.uniforms(),
        owner.style.frost,
        composeFrost: false,
      );
    } else {
      backdrop.backdropKey = batch.key;
      backdrop.filter = batch.filter;
    }
    backdrop.markNeedsAddToScene();
    addChildrenToScene(builder);
  }
}

/// Frost for one unbatched surface, clipped to its contour by the parent.
/// Batched members skip it: their batch filter composes its own frost.
/// Like [_GlassLayer], it configures a child filter layer at composition, since
/// a layer that always needs adding cannot mark itself dirty.
class _FrostLayer extends ContainerLayer {
  _RenderGlass? glass;
  // The handle keeps the child alive while it is detached between repaints.
  final _filter = LayerHandle<BackdropFilterLayer>(BackdropFilterLayer());
  BackdropFilterLayer get filter => _filter.layer!;
  double? _sigma;

  @override
  void dispose() {
    _filter.layer = null;
    super.dispose();
  }

  @override
  bool get alwaysNeedsAddToScene => true;
  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = glass;
    if (owner == null || !owner.attached) return;
    final group = owner._group;
    // Batched members compose their own frost; shared members' frost is
    // painted by the group ahead of the first shared optical pass.
    if (group != null &&
        (group.prepared[owner] != null || group.shared.contains(owner))) {
      return;
    }
    configure(owner.style.frost, null);
    addChildrenToScene(builder);
  }

  /// Sets the blur and capture key. Backdrop filters sharing a key with equal
  /// filters are rendered once over the whole capture, so the group hands each
  /// hoisted member a sigma offset below float precision of a logical pixel:
  /// every blur then stays clipped to its own contour.
  void configure(double sigma, BackdropKey? key) {
    if (sigma != _sigma) {
      _sigma = sigma;
      filter.filter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: ui.TileMode.clamp,
      );
    }
    filter
      ..backdropKey = key
      ..markNeedsAddToScene();
  }
}

/// ImageFilter.shader snapshots uniforms; reuse only when every input matches.
/// This caches the filter description, not the changing backdrop pixels.
class _GlassFilterCache {
  ui.FragmentShader? _shader;
  List<double>? _values;
  double? _frost;
  ui.ImageFilter? _filter;

  ui.ImageFilter resolve(
    ui.FragmentShader shader,
    List<double> values,
    double frost, {
    bool composeFrost = true,
  }) {
    if (!composeFrost) frost = 0;
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
    return _filter!;
  }
}

ui.ImageFilter _opticalFilter(ui.FragmentShader shader, double frost) =>
    frost > 0.05
    ? ui.ImageFilter.compose(
        outer: ui.ImageFilter.shader(shader),
        inner: ui.ImageFilter.blur(
          sigmaX: frost,
          sigmaY: frost,
          tileMode: ui.TileMode.clamp,
        ),
      )
    : ui.ImageFilter.shader(shader);

/// Kept in the original paint order unless the group paints this shadow once
/// before capturing its common backdrop. The first shared member to reach the
/// scene paints every shared member's shadow and frost here, so one capture
/// serves all of their optical passes.
class _GlassShadowLayer extends ContainerLayer {
  _GlassShadowLayer(this.glass);
  final _RenderGlass glass;
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
    if (group._hoistHost == null) {
      group._hoistHost = glass;
      group._hoist(builder, glass, glass._paintOffset);
    }
  }
}
