part of 'glass.dart';

/// One progressively blurred edge strip for [LiquidPrismEdgeBlur].
///
/// The strip is [extent] logical pixels deep from [edge]. Blur holds full
/// [sigma] for the leading [plateau] fraction, then falls off along
/// [GlassEdgeFade.curve]. A [fadeColor] adds a fade of the same depth and
/// plateau over the strip, solid at the edge up to [fadeOpacity], so blur and
/// fade track each other exactly.
@immutable
class GlassEdgeBlur {
  const GlassEdgeBlur({
    required this.edge,
    required this.extent,
    this.sigma = 0,
    this.plateau = 0,
    this.floor = 0,
    this.fadeColor,
    this.fadeOpacity = 1,
    this.fadeFloor,
    this.haze = 0,
    this.hazeOpacity = .5,
    this.hazePlateau = .34,
    this.fill = 0,
    this.fillLighten = 0,
    this.fillDarken = 0,
    this.fillNormal = 0,
  }) : assert(extent >= 0),
       assert(sigma >= 0),
       assert(plateau >= 0 && plateau < 1),
       assert(floor >= 0 && floor <= 1),
       assert(fadeOpacity >= 0 && fadeOpacity <= 1),
       assert(fadeFloor == null || (fadeFloor >= 0 && fadeFloor <= 1)),
       assert(haze >= 0),
       assert(hazeOpacity >= 0 && hazeOpacity <= 1),
       assert(hazePlateau >= 0 && hazePlateau <= 1),
       assert(fill >= 0),
       assert(fillLighten >= 0 && fillLighten <= 1),
       assert(fillDarken >= 0 && fillDarken <= 1),
       assert(fillNormal >= 0 && fillNormal <= 1);

  /// Which edge of the box the strip sits on.
  final GlassEdge edge;

  /// Depth of the strip in logical pixels.
  final double extent;

  /// Maximum Gaussian sigma at the edge, in logical pixels. Zero blurs nothing;
  /// a fade may still apply.
  final double sigma;

  /// Leading fraction of the strip (0 ≤ plateau < 1) held at full strength
  /// before the smootherstep falloff begins.
  final double plateau;

  /// Fraction of full strength the blur and fade keep at the strip's inner
  /// end, 0–1. Zero dissolves into the content; above zero the strip ends
  /// with a hard edge, as a bar with a hard scroll edge effect does.
  final double floor;

  /// Fades the strip toward this color, solid at the edge. Null fades nothing.
  final Color? fadeColor;

  /// The fade's opacity at the edge, 0–1.
  final double fadeOpacity;

  /// Fraction of the fade kept at the strip's inner end, in place of [floor].
  /// 1 holds the fade flat to the edge, as a hard scroll edge effect does.
  final double? fadeFloor;

  /// Sigma of a heavy blur blended into the strip at [hazeOpacity], the way
  /// native bars lay a 16-point blur at half opacity under their light
  /// variable blur, so fine detail softens without disappearing. Zero adds
  /// none. It runs through the engine's own blur, not the per-pixel pass.
  final double haze;

  /// The haze's opacity at the edge, 0–1.
  final double hazeOpacity;

  /// Leading fraction of the strip held at full [hazeOpacity] before it falls
  /// linearly to nothing at the inner end; 1 holds it to the edge.
  final double hazePlateau;

  /// Sigma of the blur fill: a heavy blur of the content blended back over
  /// the strip, the way native scroll edges finish their variable blur. Its
  /// three blends run in order, each weighted by its opacity times the
  /// variable blur's ramp ([plateau], [floor]): [fillLighten] lifts detail
  /// darker than its surroundings toward them, [fillDarken] pulls brighter
  /// detail down toward them, and [fillNormal] mixes the blur in. Detail
  /// loses contrast toward its own surroundings rather than toward one color.
  /// Zero adds none.
  final double fill;

  /// The blur fill's lighten opacity at full strength, 0–1.
  final double fillLighten;

  /// The blur fill's darken opacity at full strength, 0–1.
  final double fillDarken;

  /// The blur fill's normal opacity at full strength, 0–1.
  final double fillNormal;

  /// Whether the strip blends a blur fill.
  bool get fills =>
      fill > 0.01 &&
      extent > 0 &&
      (fillLighten > 0 || fillDarken > 0 || fillNormal > 0);

  /// Whether the strip blurs.
  bool get blurs => sigma > 0.01 && extent > 0;

  /// Whether the strip blends a heavy blur.
  bool get hazes => haze > 0.01 && hazeOpacity > 0 && extent > 0;

  /// Whether the strip fades.
  bool get fades =>
      fadeColor != null && fadeColor!.a > 0 && fadeOpacity > 0 && extent > 0;

  GlassEdgeBlur copyWith({
    GlassEdge? edge,
    double? extent,
    double? sigma,
    double? plateau,
    double? floor,
    Color? fadeColor,
    double? fadeOpacity,
    double? fadeFloor,
    double? haze,
    double? hazeOpacity,
    double? hazePlateau,
    double? fill,
    double? fillLighten,
    double? fillDarken,
    double? fillNormal,
  }) => GlassEdgeBlur(
    edge: edge ?? this.edge,
    extent: extent ?? this.extent,
    sigma: sigma ?? this.sigma,
    plateau: plateau ?? this.plateau,
    floor: floor ?? this.floor,
    fadeColor: fadeColor ?? this.fadeColor,
    fadeOpacity: fadeOpacity ?? this.fadeOpacity,
    fadeFloor: fadeFloor ?? this.fadeFloor,
    haze: haze ?? this.haze,
    hazeOpacity: hazeOpacity ?? this.hazeOpacity,
    hazePlateau: hazePlateau ?? this.hazePlateau,
    fill: fill ?? this.fill,
    fillLighten: fillLighten ?? this.fillLighten,
    fillDarken: fillDarken ?? this.fillDarken,
    fillNormal: fillNormal ?? this.fillNormal,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlassEdgeBlur &&
          other.fill == fill &&
          other.fillLighten == fillLighten &&
          other.fillDarken == fillDarken &&
          other.fillNormal == fillNormal &&
          other.edge == edge &&
          other.extent == extent &&
          other.sigma == sigma &&
          other.plateau == plateau &&
          other.floor == floor &&
          other.fadeColor == fadeColor &&
          other.fadeOpacity == fadeOpacity &&
          other.fadeFloor == fadeFloor &&
          other.haze == haze &&
          other.hazeOpacity == hazeOpacity &&
          other.hazePlateau == hazePlateau;

  @override
  int get hashCode => Object.hash(
    edge,
    extent,
    sigma,
    plateau,
    floor,
    fadeColor,
    fadeOpacity,
    fadeFloor,
    haze,
    hazeOpacity,
    hazePlateau,
    fill,
    fillLighten,
    fillDarken,
    fillNormal,
  );

  @override
  String toString() =>
      'GlassEdgeBlur(${edge.name}, extent: $extent, sigma: $sigma, '
      'plateau: $plateau, floor: $floor, fade: $fadeColor @ $fadeOpacity, '
      'haze: $haze @ $hazeOpacity, fill: $fill @ '
      '$fillLighten/$fillDarken/$fillNormal)';
}

/// Blurs and fades up to two opposite edges of its [child] progressively,
/// the way iOS softens content scrolled under a bar.
///
/// Each [GlassEdgeBlur] runs as a two-pass fragment shader whose sigma varies
/// per pixel across the strip, as backdrop passes clipped to the strip and
/// composited above the child, so the child paints as it would unwrapped and
/// glass inside it stays live. The fade paints over the blur.
///
/// Inside a [LiquidPrismGroup] or [LiquidPrismScaffold] the strips paint their
/// own passes in place, and glass painted after them sits on top: it captures
/// and refracts the blurred, faded content, as SwiftUI glass does over a scroll
/// edge effect. Place the effect before the group's glass in paint order.
///
/// Under an ancestor that isolates the subtree in its own pass (an `Opacity`
/// below 1, an `ImageFiltered`, a filtered `Transform`) the strips filter the
/// child's own raster instead, so the blur stays correct through such
/// transitions; glass inside is outside the supported composition there.
///
/// With no active strip (empty [edges], zero sigma and no fade, the program not
/// yet loaded, or no shader support) it paints straight through with no layer,
/// so descendant state survives the effect toggling. Animate the effect by
/// scaling [GlassEdgeBlur.sigma] and [GlassEdgeBlur.fadeOpacity]; an ancestor
/// `Opacity` does not attenuate a backdrop blur.
class LiquidPrismEdgeBlur extends StatefulWidget {
  const LiquidPrismEdgeBlur({super.key, required this.edges, this.child});

  /// Up to two strips on one axis (top and bottom, or left and right) with
  /// distinct edges.
  final List<GlassEdgeBlur> edges;

  /// The content under the strips. Null blurs whatever is painted beneath
  /// this box.
  final Widget? child;

  /// Compiles the blur program ahead of the first strip. [LiquidPrism.preload]
  /// includes it.
  static Future<void> preload() => LiquidPrism.preload();

  @override
  State<LiquidPrismEdgeBlur> createState() => _LiquidPrismEdgeBlurState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<GlassEdgeBlur>('edges', edges));
  }
}

bool _debugValidateEdges(List<GlassEdgeBlur> edges) {
  assert(edges.length <= 2, 'LiquidPrismEdgeBlur takes at most two edges');
  if (edges.length == 2) {
    assert(
      edges[0].edge != edges[1].edge,
      'LiquidPrismEdgeBlur edges must be distinct',
    );
    assert(
      edges[0].edge.isHorizontal == edges[1].edge.isHorizontal,
      'LiquidPrismEdgeBlur edges must share one axis '
      '(top and bottom, or left and right)',
    );
  }
  return true;
}

class _LiquidPrismEdgeBlurState extends State<LiquidPrismEdgeBlur> {
  bool _loading = false;

  void _ensureProgram() {
    if (LiquidPrism._edgeProgram != null ||
        !LiquidPrism.isShaderSupported ||
        _loading ||
        !widget.edges.any((edge) => edge.blurs)) {
      return;
    }
    _loading = true;
    LiquidPrism.preload()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'liquid_prism',
              context: ErrorDescription('while compiling the edge blur shader'),
            ),
          );
        })
        .whenComplete(() => _loading = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureProgram();
  }

  @override
  void didUpdateWidget(LiquidPrismEdgeBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureProgram();
  }

  @override
  Widget build(BuildContext context) {
    assert(_debugValidateEdges(widget.edges), 'invalid LiquidPrismEdgeBlur');
    return _EdgeBlurRenderWidget(
      specs: widget.edges,
      program: LiquidPrism.isShaderSupported ? LiquidPrism._edgeProgram : null,
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      child: widget.child,
    );
  }
}

class _EdgeBlurRenderWidget extends SingleChildRenderObjectWidget {
  const _EdgeBlurRenderWidget({
    required this.specs,
    required this.program,
    required this.pixelRatio,
    super.child,
  });
  final List<GlassEdgeBlur> specs;
  final ui.FragmentProgram? program;
  final double pixelRatio;

  @override
  _RenderEdgeBlur createRenderObject(BuildContext context) =>
      _RenderEdgeBlur(specs, program, pixelRatio);

  @override
  void updateRenderObject(BuildContext context, _RenderEdgeBlur renderObject) {
    renderObject
      ..program = program
      ..pixelRatio = pixelRatio
      ..specs = specs;
  }
}

/// One pass's shader and the image filter built from its current uniforms.
///
/// `ImageFilter.shader` snapshots the shader's uniforms when the filter is
/// created, so one shader serves every uniform set: it is updated in place
/// and a new filter captures it, while a filter the previous frame's scene
/// still references keeps the values it was built with. Unchanged values
/// return the same filter object, so the backdrop layer keeps its engine layer.
class _EdgePassFilter {
  _EdgePassFilter(this._shader);
  final ui.FragmentShader _shader;
  List<double> _values = const [];
  ui.ImageFilter? _filter;

  ui.ImageFilter filterFor(List<double> values) {
    final current = _filter;
    if (current != null && listEquals(values, _values)) return current;
    for (var i = 0; i < values.length; i++) {
      _shader.setFloat(2 + i, values[i]);
    }
    _values = values;
    return _filter = ui.ImageFilter.shader(_shader);
  }

  void dispose() => _shader.dispose();
}

/// Paints its child untouched, then blurs and fades the edge strips above it.
///
/// Every uniform that depends on where the box sits on screen is read at
/// scene composition, not paint: an ancestor transform (a route slide, the
/// scaled page under a sheet) moves this box without repainting it, and the
/// strip's screen origin must follow it frame by frame.
class _RenderEdgeBlur extends RenderProxyBox {
  _RenderEdgeBlur(this._specs, this._program, this.pixelRatio);

  final _contentLayer = LayerHandle<_EdgeContentLayer>();
  final _inputClipLayer = LayerHandle<ClipRectLayer>();
  final _stripClipLayers = [
    LayerHandle<ClipPathLayer>(),
    LayerHandle<ClipPathLayer>(),
  ];
  final _passLayers = [
    LayerHandle<_EdgePassLayer>(),
    LayerHandle<_EdgePassLayer>(),
  ];
  final _fadeLayer = LayerHandle<_EdgeFadeLayer>();
  final _hazeClipLayer = LayerHandle<ClipPathLayer>();
  final _hazeLayer = LayerHandle<_EdgeBackdropLayer>();
  ({double sigma, ui.ImageFilter filter})? _hazeBlur;
  final _fillClipLayer = LayerHandle<ClipPathLayer>();
  final _fillLayers = [
    for (var i = 0; i < _fillModes.length; i++)
      LayerHandle<_EdgeBackdropLayer>(),
  ];
  ({double sigma, ui.ImageFilter filter})? _fillBlur;

  /// The blur fill's blends, in the order they run.
  static const _fillModes = [
    BlendMode.lighten,
    BlendMode.darken,
    BlendMode.srcOver,
  ];

  static double _fillOpacity(GlassEdgeBlur spec, BlendMode mode) =>
      switch (mode) {
        BlendMode.lighten => spec.fillLighten,
        BlendMode.darken => spec.fillDarken,
        _ => spec.fillNormal,
      };

  List<_EdgePassFilter>? _screenFilters;
  List<_EdgePassFilter>? _textureFilters;
  ({ui.ImageFilter inner, ui.ImageFilter outer, ui.ImageFilter filter})?
  _textureCompose;

  List<_EdgePassFilter> _createPassFilters() => [
    _EdgePassFilter(LiquidPrism._createEdgeShader()!),
    _EdgePassFilter(LiquidPrism._createEdgeShader()!),
  ];

  /// Whether the content layer found an isolating ancestor when it was last
  /// composited; the pass layers, composited right after it, read this.
  bool _isolated = false;

  List<GlassEdgeBlur> _specs;
  List<GlassEdgeBlur> get specs => _specs;
  set specs(List<GlassEdgeBlur> value) {
    if (listEquals(value, _specs)) return;
    final wasActive = _isActive;
    _specs = value;
    if (_isActive != wasActive) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  ui.FragmentProgram? _program;
  ui.FragmentProgram? get program => _program;
  set program(ui.FragmentProgram? value) {
    if (identical(value, _program)) return;
    final wasActive = _isActive;
    _program = value;
    _disposeFilters();
    if (_isActive != wasActive) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// Physical px per logical px of the screen the box is composited onto.
  double pixelRatio;

  /// Strips that blur, given a program to run them.
  Iterable<GlassEdgeBlur> get _blurs =>
      _program == null ? const [] : _specs.where((spec) => spec.blurs);
  Iterable<GlassEdgeBlur> get _fades => _specs.where((spec) => spec.fades);
  Iterable<GlassEdgeBlur> get _hazes => LiquidPrism._edgeProgram == null
      ? const []
      : _specs.where((spec) => spec.hazes);
  Iterable<GlassEdgeBlur> get _fills => LiquidPrism._edgeProgram == null
      ? const []
      : _specs.where((spec) => spec.fills);
  bool get _blurring => _blurs.isNotEmpty;
  bool get _hazing => _hazes.isNotEmpty;
  bool get _filling => _fills.isNotEmpty;
  bool get _isActive => _blurring || _hazing || _filling || _fades.isNotEmpty;
  bool get hasChild => child != null;

  @override
  bool get alwaysNeedsCompositing => _isActive;

  @override
  void detach() {
    _contentLayer.layer?.blur = null;
    _fadeLayer.layer?.blur = null;
    _hazeLayer.layer?.blur = null;
    for (final handle in _passLayers) {
      handle.layer?.blur = null;
    }
    for (final handle in _fillLayers) {
      handle.layer?.blur = null;
    }
    super.detach();
  }

  @override
  void dispose() {
    _releaseLayers();
    _disposeFilters();
    _fadePicture?.dispose();
    super.dispose();
  }

  void _releaseLayers() {
    _contentLayer.layer?.blur = null;
    _contentLayer.layer = null;
    _inputClipLayer.layer = null;
    _fadeLayer.layer?.blur = null;
    _fadeLayer.layer = null;
    _hazeClipLayer.layer = null;
    _hazeLayer.layer?.blur = null;
    _hazeLayer.layer = null;
    _releaseFillLayers();
    for (var pass = 0; pass < 2; pass++) {
      _stripClipLayers[pass].layer = null;
      _passLayers[pass].layer?.blur = null;
      _passLayers[pass].layer = null;
    }
  }

  void _releaseFillLayers() {
    _fillClipLayer.layer = null;
    for (final handle in _fillLayers) {
      handle.layer?.blur = null;
      handle.layer = null;
    }
  }

  void _disposeFilters() {
    for (final filter in [...?_screenFilters, ...?_textureFilters]) {
      filter.dispose();
    }
    _hazeBlur = null;
    _fillBlur = null;
    _screenFilters = null;
    _textureFilters = null;
    _textureCompose = null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_isActive || size.isEmpty) {
      _releaseLayers();
      super.paint(context, offset);
      return;
    }
    final content = _contentLayer.layer ??= _EdgeContentLayer();
    content
      ..blur = this
      ..paintOffset = offset;
    context.pushLayer(content, _paintContent, offset);

    if (_blurring) {
      final strips = _stripPath(_blurs);
      final bounds = strips.getBounds();
      for (var pass = 0; pass < 2; pass++) {
        final passLayer = _passLayers[pass].layer ??= _EdgePassLayer(pass);
        passLayer.blur = this;
        _stripClipLayers[pass].layer = context.pushClipPath(
          needsCompositing,
          offset,
          bounds,
          strips,
          (context, offset) => context.pushLayer(
            passLayer,
            (context, offset) =>
                context.pushLayer(passLayer.filter, (_, _) {}, offset),
            offset,
          ),
          clipBehavior: Clip.hardEdge,
          oldLayer: _stripClipLayers[pass].layer,
        );
      }
    } else {
      for (var pass = 0; pass < 2; pass++) {
        _stripClipLayers[pass].layer = null;
        _passLayers[pass].layer?.blur = null;
        _passLayers[pass].layer = null;
      }
    }
    if (_filling) {
      final strips = _stripPath(_fills);
      _fillClipLayer.layer = context.pushClipPath(
        needsCompositing,
        offset,
        strips.getBounds(),
        strips,
        (context, offset) {
          for (var i = 0; i < _fillModes.length; i++) {
            final mode = _fillModes[i];
            if (!_fills.any((spec) => _fillOpacity(spec, mode) > 0)) {
              _fillLayers[i].layer?.blur = null;
              _fillLayers[i].layer = null;
              continue;
            }
            final fill = _fillLayers[i].layer ??= _EdgeBackdropLayer(
              (owner) => owner._fillScreenFilter(),
              blendMode: mode,
            );
            fill.blur = this;
            context.pushLayer(
              fill,
              (context, offset) =>
                  context.pushLayer(fill.filter, (context, offset) {
                    final canvas = context.canvas
                      ..save()
                      ..translate(offset.dx, offset.dy);
                    _paintFillWeights(canvas, mode);
                    canvas.restore();
                  }, offset),
              offset,
            );
          }
        },
        clipBehavior: Clip.hardEdge,
        oldLayer: _fillClipLayer.layer,
      );
    } else {
      _releaseFillLayers();
    }
    if (_hazing) {
      final strips = _stripPath(_hazes);
      final haze = _hazeLayer.layer ??= _EdgeBackdropLayer(
        (owner) => owner._hazeScreenFilter(),
      );
      haze.blur = this;
      _hazeClipLayer.layer = context.pushClipPath(
        needsCompositing,
        offset,
        strips.getBounds(),
        strips,
        (context, offset) => context.pushLayer(
          haze,
          (context, offset) =>
              context.pushLayer(haze.filter, (context, offset) {
                final canvas = context.canvas
                  ..save()
                  ..translate(offset.dx, offset.dy);
                _paintHazeWeights(canvas);
                canvas.restore();
              }, offset),
          offset,
        ),
        clipBehavior: Clip.hardEdge,
        oldLayer: _hazeClipLayer.layer,
      );
    } else {
      _hazeClipLayer.layer = null;
      _hazeLayer.layer?.blur = null;
      _hazeLayer.layer = null;
    }
    if (_fades.isNotEmpty) {
      final fade = _fadeLayer.layer ??= _EdgeFadeLayer();
      fade
        ..blur = this
        ..offset = offset;
      context.pushLayer(fade, (_, _) {}, offset);
    } else {
      _fadeLayer.layer?.blur = null;
      _fadeLayer.layer = null;
    }
  }

  /// The strips [specs] cover, in this box's coordinates.
  Path _stripPath(Iterable<GlassEdgeBlur> specs) {
    final path = Path();
    for (final spec in specs) {
      path.addRect(_stripRect(spec));
    }
    return path;
  }

  /// The strip a spec covers, in this box's coordinates, clamped to its size.
  Rect _stripRect(GlassEdgeBlur spec) {
    final width = size.width;
    final height = size.height;
    return switch (spec.edge) {
      GlassEdge.top => Rect.fromLTWH(0, 0, width, spec.extent.clamp(0, height)),
      GlassEdge.bottom => Rect.fromLTWH(
        0,
        height - spec.extent.clamp(0, height),
        width,
        spec.extent.clamp(0, height),
      ),
      GlassEdge.left => Rect.fromLTWH(
        0,
        0,
        spec.extent.clamp(0, width),
        height,
      ),
      GlassEdge.right => Rect.fromLTWH(
        width - spec.extent.clamp(0, width),
        0,
        spec.extent.clamp(0, width),
        height,
      ),
    };
  }

  /// Paints the child clipped to the box. The texture frame measures its
  /// strips from the edges of the filter's input texture, which spans the
  /// child's painted coverage: content painting outside the bounds (shadows,
  /// overflow) would grow it mid-scroll and make the strips jump.
  void _paintContent(PaintingContext context, Offset offset) {
    _inputClipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintCoveragePinnedChild,
      oldLayer: _inputClipLayer.layer,
    );
  }

  /// Pins the texture frame's painted coverage to the full box before painting
  /// the child, whose own painting may start inside it (a list whose
  /// transparent top padding shows the background). The engine sizes that
  /// frame's input texture to painted coverage, so an under-covered texture
  /// would displace the strips as scrolling moves the first painted pixel.
  /// 1/255 alpha is imperceptible, while a fully transparent draw may be
  /// culled and not count toward coverage.
  void _paintCoveragePinnedChild(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.canvas.drawRect(offset & size, _coveragePaint);
    super.paint(context, offset);
  }

  static final Paint _coveragePaint = Paint()..color = const Color(0x01000000);

  ui.Picture? _fadePicture;
  List<Object> _fadeSignature = const [];

  /// The fade strips as a picture in this box's enclosing layer space.
  ui.Picture _fadeFor(Offset offset) {
    final signature = <Object>[offset, size, ..._fades];
    if (_fadePicture != null && listEquals(signature, _fadeSignature)) {
      return _fadePicture!;
    }
    _fadeSignature = signature;
    _fadePicture?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..translate(offset.dx, offset.dy);
    _drawFades(canvas);
    return _fadePicture = recorder.endRecording();
  }

  /// Paints the fade strips, clipped to the box by the same hard edge that
  /// clips the content in [_paintContent].
  ///
  /// Each strip overhangs the box by [_fadeBleed] on its outer edge and both
  /// sides, so the clip alone decides how much of a partly covered edge pixel
  /// the strip owns, by the same rule that decides the content's share. A
  /// strip that stopped exactly at the box edge would cover that pixel by its
  /// own anti-aliasing instead, and a box at a fractional position (any
  /// scroll offset) would show a hairline of unfaded content along the edge.
  /// The gradient stays anchored on the true strip; its clamped end holds the
  /// solid color through the overhang.
  ///
  /// The paint is not anti-aliased, which keeps it off Impeller's SDF renderer
  /// (opt-in on iOS, on by default on desktop). Since Flutter 3.50 that
  /// renderer shades linear gradients itself without the ordered dither the
  /// gradient pipelines apply (flutter/flutter#192124, #192962), so a long,
  /// low-contrast fade bands into visible steps. The strip needs no edge
  /// anti-aliasing of its own while the clip shapes its edges; restore it once
  /// UberSDF gradients dither.
  void _drawFades(Canvas canvas) {
    canvas
      ..save()
      ..clipRect(Offset.zero & size, doAntiAlias: false);
    for (final spec in _fades) {
      final rect = _stripRect(spec);
      if (rect.isEmpty) continue;
      canvas.drawRect(
        _overhang(rect, spec.edge),
        Paint()
          ..isAntiAlias = false
          ..shader = GlassEdgeFade.shader(
            color: spec.fadeColor!,
            rect: rect,
            edge: spec.edge,
            plateau: spec.plateau,
            floor: spec.fadeFloor ?? spec.floor,
            opacity: spec.fadeOpacity,
          ),
      );
    }
    canvas.restore();
  }

  /// How far a fade strip overhangs the box past each edge it shares with the
  /// box. One logical pixel spans more than the half physical pixel an
  /// anti-aliased edge reaches outward at any scale above a sixth.
  static const _fadeBleed = 1.0;

  /// [strip] grown by [_fadeBleed] past the box on its outer edge and both
  /// sides. The inner edge, where the fade ends inside the box, stays put.
  static Rect _overhang(Rect strip, GlassEdge edge) {
    const bleed = _fadeBleed;
    return switch (edge) {
      GlassEdge.top => Rect.fromLTRB(
        strip.left - bleed,
        strip.top - bleed,
        strip.right + bleed,
        strip.bottom,
      ),
      GlassEdge.bottom => Rect.fromLTRB(
        strip.left - bleed,
        strip.top,
        strip.right + bleed,
        strip.bottom + bleed,
      ),
      GlassEdge.left => Rect.fromLTRB(
        strip.left - bleed,
        strip.top - bleed,
        strip.right,
        strip.bottom + bleed,
      ),
      GlassEdge.right => Rect.fromLTRB(
        strip.left,
        strip.top - bleed,
        strip.right + bleed,
        strip.bottom + bleed,
      ),
    };
  }

  /// The self-contained two-pass filter for the texture frame, rebuilt only
  /// when the strips or the size change.
  ui.ImageFilter _textureFrameFilter() {
    final passes = _textureFilters ??= _createPassFilters();
    final horizontal = passes[0].filterFor(
      _uniforms(pass: 0, frame: _textureFrame),
    );
    final vertical = passes[1].filterFor(
      _uniforms(pass: 1, frame: _textureFrame),
    );
    final cached = _textureCompose;
    if (cached != null &&
        identical(cached.inner, horizontal) &&
        identical(cached.outer, vertical)) {
      return cached.filter;
    }
    final filter = ui.ImageFilter.compose(outer: vertical, inner: horizontal);
    _textureCompose = (inner: horizontal, outer: vertical, filter: filter);
    return filter;
  }

  /// Where the box sits on the screen at this composition: its top-left in
  /// physical px and the matrix taking logical box px to physical px.
  Offset _screenOrigin = Offset.zero;
  (double, double, double, double) _screenMatrix = (1, 0, 0, 1);

  void _locateOnScreen() {
    final transform = getTransformTo(null);
    final m = transform.storage;
    final dpr = pixelRatio;
    _screenOrigin = MatrixUtils.transformPoint(transform, Offset.zero) * dpr;
    _screenMatrix = (m[0] * dpr, m[1] * dpr, m[4] * dpr, m[5] * dpr);
  }

  /// One backdrop pass in the screen frame, located from the box's current
  /// transform to the root.
  ui.ImageFilter _screenFrameFilter(int pass) {
    final passes = _screenFilters ??= _createPassFilters();
    return passes[pass].filterFor(
      _uniforms(
        pass: pass,
        frame: _screenFrame,
        origin: _screenOrigin,
        matrix: _screenMatrix,
      ),
    );
  }

  static const _screenFrame = 0.0;
  static const _textureFrame = 1.0;

  /// The haze: the engine's blur at the strips' sigma, as the backdrop
  /// filter itself. Impeller limits a top-level blur to its clip; composed
  /// under a shader it would blur the whole captured screen every frame. Its
  /// backdrop layer's child ([_paintHazeWeights]) then scales the blurred
  /// strip by the per-row weight, so the layer composites the blur in.
  ui.ImageFilter _hazeScreenFilter() {
    var sigma = 0.0;
    for (final spec in _hazes) {
      sigma = math.max(sigma, spec.haze);
    }
    final cached = _hazeBlur;
    if (cached != null && cached.sigma == sigma) return cached.filter;
    final filter = ui.ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: ui.TileMode.clamp,
    );
    _hazeBlur = (sigma: sigma, filter: filter);
    return filter;
  }

  /// The blur fill's engine blur, as each fill layer's backdrop filter.
  ui.ImageFilter _fillScreenFilter() {
    var sigma = 0.0;
    for (final spec in _fills) {
      sigma = math.max(sigma, spec.fill);
    }
    final cached = _fillBlur;
    if (cached != null && cached.sigma == sigma) return cached.filter;
    final filter = ui.ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      tileMode: ui.TileMode.clamp,
    );
    _fillBlur = (sigma: sigma, filter: filter);
    return filter;
  }

  /// Multiplies a fill layer's blurred strips by the [mode] blend's weight
  /// (`dstIn`): its opacity along the variable blur's ramp. Every filling
  /// strip is painted, at zero where this blend has no opacity, so no strip
  /// keeps the unweighted blur.
  void _paintFillWeights(Canvas canvas, BlendMode mode) {
    for (final spec in _fills) {
      final rect = _stripRect(spec);
      if (rect.isEmpty) continue;
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = GlassEdgeFade.shader(
            color: const Color(0xFF000000),
            rect: rect,
            edge: spec.edge,
            plateau: spec.plateau,
            floor: spec.floor,
            opacity: _fillOpacity(spec, mode),
          ),
      );
    }
  }

  /// Multiplies the haze layer's blurred strips by their weight in this box's
  /// space (`dstIn`): the haze opacity held over the leading plateau
  /// fraction, then falling linearly to zero at the strip's far end.
  void _paintHazeWeights(Canvas canvas) {
    for (final spec in _hazes) {
      final rect = _stripRect(spec);
      if (rect.isEmpty) continue;
      final (begin, end) = switch (spec.edge) {
        GlassEdge.top => (rect.topCenter, rect.bottomCenter),
        GlassEdge.bottom => (rect.bottomCenter, rect.topCenter),
        GlassEdge.left => (rect.centerLeft, rect.centerRight),
        GlassEdge.right => (rect.centerRight, rect.centerLeft),
      };
      final weight = Color.from(
        alpha: spec.hazeOpacity,
        red: 0,
        green: 0,
        blue: 0,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            begin,
            end,
            [weight, weight, weight.withValues(alpha: 0)],
            [0, spec.hazePlateau.clamp(0, 1), 1],
          ),
      );
    }
  }

  /// The shader's float uniforms in declaration order after the engine-set
  /// texture size: u_pass, u_box, u_matrix, u_inverse, u_start, u_end. All
  /// lengths are in logical px; the frame's matrix takes them to texture px.
  List<double> _uniforms({
    required int pass,
    required double frame,
    Offset origin = Offset.zero,
    (double, double, double, double) matrix = (1, 0, 0, 1),
  }) {
    GlassEdgeBlur? start;
    GlassEdgeBlur? end;
    for (final spec in _blurs) {
      if (spec.edge.isStart) {
        start = spec;
      } else {
        end = spec;
      }
    }
    final edge = (start ?? end)!.edge;
    final (a, b, c, d) = matrix;
    final det = a * d - b * c;
    final inverse = det.abs() < 1e-9
        ? (1.0, 0.0, 0.0, 1.0)
        : (d / det, -b / det, -c / det, a / det);
    return [
      pass.toDouble(),
      edge.isHorizontal ? 1 : 0,
      frame,
      size.width,
      size.height,
      origin.dx,
      origin.dy,
      0,
      a,
      b,
      c,
      d,
      inverse.$1,
      inverse.$2,
      inverse.$3,
      inverse.$4,
      start?.extent ?? 0,
      start?.sigma ?? 0,
      start?.plateau ?? 0,
      start?.floor ?? 0,
      end?.extent ?? 0,
      end?.sigma ?? 0,
      end?.plateau ?? 0,
      end?.floor ?? 0,
    ];
  }
}

/// Whether an ancestor composites [layer]'s subtree through its own offscreen
/// pass, so a backdrop read inside it sees that pass rather than the screen.
bool _isolatesBackdrop(Layer layer) {
  for (Layer? ancestor = layer.parent; ancestor != null;) {
    final isolating = switch (ancestor) {
      OpacityLayer(:final alpha) => alpha != null && alpha < 255,
      ImageFilterLayer() ||
      ShaderMaskLayer() ||
      ColorFilterLayer() ||
      BackdropFilterLayer() => true,
      ClipRectLayer(:final clipBehavior) ||
      ClipRRectLayer(:final clipBehavior) ||
      ClipRSuperellipseLayer(:final clipBehavior) ||
      ClipPathLayer(
        :final clipBehavior,
      ) => clipBehavior == Clip.antiAliasWithSaveLayer,
      _ => false,
    };
    if (isolating) return true;
    ancestor = ancestor.parent;
  }
  return false;
}

/// Holds the child's paint. Composited plainly in the screen frame; in an
/// isolated subtree it wraps the child in the texture-frame image filter,
/// clipped to the box so the filter's padded output cannot smear a hairline
/// of edge content just outside it.
class _EdgeContentLayer extends ContainerLayer {
  _RenderEdgeBlur? blur;

  /// Where the child was painted in this layer's coordinates.
  Offset paintOffset = Offset.zero;

  ui.ClipRectEngineLayer? _outputClip;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void dispose() {
    _outputClip?.dispose();
    _outputClip = null;
    super.dispose();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = blur;
    final isolated = owner != null && owner.attached && _isolatesBackdrop(this);
    owner?._isolated = isolated;
    if (!isolated || !owner.hasChild || !owner._blurring) {
      if (owner != null && owner.attached) owner._locateOnScreen();
      engineLayer = null;
      addChildrenToScene(builder);
      return;
    }
    final previousClip = _outputClip;
    _outputClip = builder.pushClipRect(
      paintOffset & owner.size,
      oldLayer: previousClip,
    );
    previousClip?.dispose();
    engineLayer = builder.pushImageFilter(
      owner._textureFrameFilter(),
      oldLayer: engineLayer as ui.ImageFilterEngineLayer?,
    );
    addChildrenToScene(builder);
    builder
      ..pop()
      ..pop();
  }
}

/// One blur pass over the strips, as a backdrop filter whose uniforms follow
/// the box's screen transform at composition. Adds nothing while the subtree
/// is isolated (the content layer blurs in the texture frame instead).
class _EdgePassLayer extends ContainerLayer {
  _EdgePassLayer(this.pass);

  /// 0 = horizontal, 1 = vertical.
  final int pass;
  _RenderEdgeBlur? blur;

  // The handle keeps the child alive while it is detached between repaints.
  final _filter = LayerHandle<BackdropFilterLayer>(BackdropFilterLayer());
  BackdropFilterLayer get filter => _filter.layer!;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void dispose() {
    _filter.layer = null;
    super.dispose();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = blur;
    if (owner == null || !owner.attached) return;
    if (owner._isolated && owner.hasChild) return;
    filter
      ..filter = owner._screenFrameFilter(pass)
      ..backdropKey = null;
    final clip = compositedAncestorClip(this);
    if (clip != null) builder.pushClipPath(clip);
    addChildrenToScene(builder);
    if (clip != null) builder.pop();
  }
}

/// A heavy engine blur over the strips, composited onto them by [blendMode]
/// at a per-row weight its child paints: the haze, and each blend of the blur
/// fill. Adds nothing while isolated.
class _EdgeBackdropLayer extends ContainerLayer {
  _EdgeBackdropLayer(this.filterOf, {BlendMode blendMode = BlendMode.srcOver})
    : _filter = LayerHandle<BackdropFilterLayer>(
        BackdropFilterLayer(blendMode: blendMode),
      );

  /// The owner's current blur for this layer.
  final ui.ImageFilter Function(_RenderEdgeBlur owner) filterOf;
  _RenderEdgeBlur? blur;
  final LayerHandle<BackdropFilterLayer> _filter;
  BackdropFilterLayer get filter => _filter.layer!;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void dispose() {
    _filter.layer = null;
    super.dispose();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = blur;
    if (owner == null || !owner.attached) return;
    if (owner._isolated) return;
    filter
      ..filter = filterOf(owner)
      ..backdropKey = null;
    final clip = compositedAncestorClip(this);
    if (clip != null) builder.pushClipPath(clip);
    addChildrenToScene(builder);
    if (clip != null) builder.pop();
  }
}

/// The fade over the strips, painted after the blur.
class _EdgeFadeLayer extends ContainerLayer {
  _RenderEdgeBlur? blur;
  Offset offset = Offset.zero;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final owner = blur;
    if (owner == null || !owner.attached) return;
    final clip = compositedAncestorClip(this);
    if (clip != null) builder.pushClipPath(clip);
    builder.addPicture(Offset.zero, owner._fadeFor(offset));
    if (clip != null) builder.pop();
  }
}
