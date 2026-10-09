import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'style.dart';
import 'superellipse.dart';
import 'material.dart';
import 'theme.dart';
import 'recipe.dart';
import 'pressable.dart';

part 'glass_group.dart';

/// A live backdrop lens. Foreground content stays sharp above the material.
///
/// Call [preload] before runApp to compile the program before the first lens.
/// Refraction uses Flutter shader filters on Impeller; unsupported renderers
/// use a frosted fallback.
/// Ancestor ImageFiltered/Opacity saveLayers isolate the backdrop and are
/// outside the supported composition.
class LiquidPrism extends StatefulWidget {
  const LiquidPrism({
    super.key,
    this.glass,
    this.blur,
    this.optics,
    this.shape,
    this.child,
    this.role = GlassRole.surface,
  }) : assert(blur == null || (blur >= 0 && blur <= 12));
  final Glass? glass;
  final double? blur;

  /// Expert optics override the material recipe. Shape and fluent tint still apply.
  final LiquidPrismStyle? optics;

  /// Defaults to capsule, or the advanced style's corner radius when provided.
  final GlassShape? shape;
  @internal
  final GlassRole role;
  final Widget? child;
  static ui.FragmentProgram? _program;
  static ui.FragmentProgram? _batchProgram;
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
    final recipe = GlassRecipe.resolve(
      _material,
      LiquidPrismTheme.brightnessOf(context),
      widget.role,
      customOptics: optics != null,
    );
    final style = (optics ?? recipe.optics(shape.radius)).copyWith(
      cornerRadius: shape.radius,
      frost:
          widget.blur ??
          (widget.optics != null ? widget.optics!.frost : theme.blur),
    );
    final shader = _shader;
    final press = LiquidPrismPressFeedback.of(context);
    final fallbackTint = Color.alphaBlend(
      _material.tintColor ?? const Color(0x00000000),
      optics?.tint ?? Color(recipe.dark ? 0x99000000 : 0x99FFFFFF),
    );
    return CustomPaint(
      painter: shader == null ? _ExteriorShadow(shape) : null,
      child: shader != null
          ? _GlassRenderWidget(
              shader: shader,
              style: style,
              shape: shape,
              recipe: recipe,
              press: press,
              group: _GlassGroupScope.of(context),
              pixelRatio: MediaQuery.devicePixelRatioOf(context),
              child: ClipPath(
                clipper: GlassShapeClipper(shape),
                child: widget.child ?? const SizedBox.shrink(),
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
                  child: widget.child ?? const SizedBox.shrink(),
                ),
              ),
            ),
    );
  }
}

/// Contact and soft shadows only darken pixels outside the glass.
class _ExteriorShadow extends CustomPainter {
  const _ExteriorShadow(this.shape);
  final GlassShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outline = shape.path(size);
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(48))
        ..addPath(outline, Offset.zero),
    );
    canvas.drawPath(
      outline.shift(const Offset(0, 1)),
      Paint()
        ..color = const Color(0x06000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      outline.shift(const Offset(0, 3)),
      Paint()
        ..color = const Color(0x05000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ExteriorShadow oldDelegate) => shape != oldDelegate.shape;
}

class _GlassRenderWidget extends SingleChildRenderObjectWidget {
  const _GlassRenderWidget({
    required this.shader,
    required this.style,
    required this.shape,
    required this.recipe,
    required this.press,
    required this.group,
    required this.pixelRatio,
    super.child,
  });
  final ui.FragmentShader shader;
  final LiquidPrismStyle style;
  final GlassShape shape;
  final GlassRecipe recipe;
  final double press;
  final _GlassGroupData? group;
  final double pixelRatio;
  @override
  _RenderGlass createRenderObject(BuildContext context) =>
      _RenderGlass(shader, style, shape, recipe, press, pixelRatio, group);
  @override
  void updateRenderObject(BuildContext context, _RenderGlass renderObject) {
    renderObject
      ..shader = shader
      ..style = style
      ..shape = shape
      ..recipe = recipe
      ..press = press
      ..group = group
      ..pixelRatio = pixelRatio
      ..markNeedsPaint();
  }
}

class _RenderGlass extends RenderProxyBox {
  _RenderGlass(
    this.shader,
    this.style,
    this.shape,
    this.recipe,
    this.press,
    this.pixelRatio,
    this._group,
  );
  ui.FragmentShader shader;
  LiquidPrismStyle style;
  GlassShape shape;
  GlassRecipe recipe;
  double press;
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
  @override
  bool get alwaysNeedsCompositing => true;
  Size? _contourSize;
  GlassShape? _contourShape;
  List<double> _contour = List.filled(12, 0);
  List<double> uniforms() {
    if (size != _contourSize || shape != _contourShape) {
      _contourSize = size;
      _contourShape = shape;
      _contour = shape.isSmooth
          ? superellipseUniforms(size, shape.radius)
          : List.filled(12, 0);
    }
    final transform = getTransformTo(null);
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
    ];
    values[33] = press;
    values[37] = shape.isSmooth && shape.radius > .001 ? 1 : 0;
    return values;
  }

  void pack() {
    final values = uniforms();
    for (var i = 2; i < values.length; i++) {
      shader.setFloat(i, values[i]);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    final shadow = _shadowLayer.layer ??= _GlassShadowLayer(this);
    context.pushLayer(shadow, (context, offset) {
      final canvas = context.canvas;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      _ExteriorShadow(shape).paint(canvas, size);
      canvas.restore();
    }, offset);
    final layer = _glassLayer.layer ??= _GlassLayer();
    layer.glass = this;
    layer.filter = _filterLayer.layer ??= BackdropFilterLayer();
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      (Offset.zero & size).inflate(2),
      (context, offset) => context.pushLayer(
        layer,
        (context, offset) =>
            context.pushLayer(layer.filter!, (context, offset) {}, offset),
        offset,
      ),
      oldLayer: _clipLayer.layer,
    );
    super.paint(context, offset);
  }

  @override
  void detach() {
    _group?.members.remove(this);
    _glassLayer.layer?.glass = null;
    super.detach();
  }

  @override
  void dispose() {
    _glassLayer.layer?.glass = null;
    _shadowLayer.layer = null;
    _glassLayer.layer = null;
    _filterLayer.layer = null;
    _clipLayer.layer = null;
    super.dispose();
  }
}

/// Uniforms follow retained scroll/transform layers at scene composition time.
class _GlassLayer extends ContainerLayer {
  _RenderGlass? glass;
  BackdropFilterLayer? filter;
  @override
  bool get alwaysNeedsAddToScene => true;
  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = glass;
    if (owner == null || !owner.attached) return;
    final batch = owner._group?.prepared[owner];
    final backdrop = filter!;
    if (batch == null) {
      owner.pack();
      backdrop.backdropKey = null;
      backdrop.filter = _opticalFilter(owner.shader, owner.style.frost);
    } else {
      backdrop.backdropKey = batch.key;
      backdrop.filter = batch.filter;
    }
    backdrop.markNeedsAddToScene();
    addChildrenToScene(builder);
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
/// before capturing its common backdrop.
class _GlassShadowLayer extends ContainerLayer {
  _GlassShadowLayer(this.glass);
  final _RenderGlass glass;
  @override
  bool get alwaysNeedsAddToScene => true;
  @override
  void addToScene(ui.SceneBuilder builder) {
    if (glass.attached && glass._group?.prepared.containsKey(glass) != true) {
      addChildrenToScene(builder);
    }
  }
}
