part of 'glass.dart';

/// Shares an optical pass between independent glass controls over one backdrop.
///
/// Keep intervening content outside this group: members must see the same
/// background, painted outside the group. Nearby and overlapping glass
/// automatically use separate passes. Only regular material at unit scale on
/// physical pixel boundaries is batched. Tab bars, clear/expert optics and
/// members under an intermediate clip keep their individual rendering path.
/// Unbatched members whose sampling never reaches another member's paint share
/// one backdrop capture while keeping their own filter.
/// This changes rendering work only; surfaces do not merge or morph.
class LiquidPrismGroup extends StatefulWidget {
  const LiquidPrismGroup({super.key, required this.child});
  final Widget child;
  @override
  State<LiquidPrismGroup> createState() => _LiquidPrismGroupState();
}

class _LiquidPrismGroupState extends State<LiquidPrismGroup> {
  final _data = _GlassGroupData();
  @override
  Widget build(BuildContext context) => _GlassGroupScope(
    data: _data,
    child: _GlassGroupRenderWidget(data: _data, child: widget.child),
  );
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('batchedSurfaces', _data.prepared.length))
      ..add(IntProperty('opticalBatches', _data._batches.length))
      ..add(IntProperty('sharedBackdropSurfaces', _data.shared.length));
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }
}

/// Owns a group whose members are only the surfaces below a
/// [GlassGroupMembers] in its subtree. [LiquidPrismScaffold] hosts one around
/// its layout and scopes the floating chrome, so the body it paints first is
/// never a member while the tab bar, leading control and actions share
/// captures.
@internal
class GlassGroupHost extends StatefulWidget {
  const GlassGroupHost({super.key, required this.child});
  final Widget child;
  @override
  State<GlassGroupHost> createState() => _GlassGroupHostState();
}

class _GlassGroupHostState extends State<GlassGroupHost> {
  final _data = _GlassGroupData();
  @override
  Widget build(BuildContext context) => _GlassGroupHostScope(
    data: _data,
    child: _GlassGroupRenderWidget(data: _data, child: widget.child),
  );
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('batchedSurfaces', _data.prepared.length))
      ..add(IntProperty('opticalBatches', _data._batches.length))
      ..add(IntProperty('sharedBackdropSurfaces', _data.shared.length));
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }
}

class _GlassGroupHostScope extends InheritedWidget {
  const _GlassGroupHostScope({required this.data, required super.child});
  final _GlassGroupData data;
  @override
  bool updateShouldNotify(_GlassGroupHostScope oldWidget) =>
      data != oldWidget.data;
}

/// Joins the surfaces below it to the nearest [GlassGroupHost]. Members must
/// see the same background, painted before all of them; keep content that
/// paints between members outside.
@internal
class GlassGroupMembers extends StatelessWidget {
  const GlassGroupMembers({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final host = context
        .dependOnInheritedWidgetOfExactType<_GlassGroupHostScope>();
    if (host == null) return child;
    return _GlassGroupScope(data: host.data, child: child);
  }
}

class _GlassGroupScope extends InheritedWidget {
  const _GlassGroupScope({required this.data, required super.child});
  final _GlassGroupData data;
  static _GlassGroupData? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassGroupScope>()?.data;
  @override
  bool updateShouldNotify(_GlassGroupScope oldWidget) => data != oldWidget.data;
}

class _GlassGroupRenderWidget extends SingleChildRenderObjectWidget {
  const _GlassGroupRenderWidget({required this.data, required super.child});
  final _GlassGroupData data;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassGroup(data);
}

class _RenderGlassGroup extends RenderProxyBox {
  _RenderGlassGroup(this.data);
  final _GlassGroupData data;
  final _layer = LayerHandle<_GlassGroupLayer>();
  @override
  bool get alwaysNeedsCompositing => true;
  @override
  void paint(PaintingContext context, Offset offset) {
    final layer = _layer.layer ??= _GlassGroupLayer(data, this);
    layer.offset = offset;
    context.pushLayer(layer, super.paint, offset);
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}

class _GlassGroupLayer extends ContainerLayer {
  _GlassGroupLayer(this.data, this.renderBox);
  final _GlassGroupData data;
  final _RenderGlassGroup renderBox;
  Offset offset = Offset.zero;
  ui.Picture? _shadows;
  List<Object> _signature = [];
  void _prepareShadows() {
    final signature = <Object>[offset];
    final transforms = <_RenderGlass, Matrix4>{};
    for (final member in data.prepared.keys) {
      final matrix = member.getTransformTo(renderBox);
      transforms[member] = matrix;
      signature.addAll([
        member.shape,
        member.size,
        member.recipe.shadowStrength,
        member.recipe.usesNativeControlShadow,
        ...matrix.storage,
      ]);
    }
    if (listEquals(_signature, signature)) return;
    _signature = signature;
    _shadows?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..translate(offset.dx, offset.dy);
    for (final entry in transforms.entries) {
      canvas.save();
      canvas.transform(entry.value.storage);
      _ExteriorShadow(
        entry.key.shape,
        strength: entry.key.recipe.shadowStrength,
        nativeControl: entry.key.recipe.usesNativeControlShadow,
      ).paint(canvas, entry.key.size);
      canvas.restore();
    }
    _shadows = recorder.endRecording();
  }

  @override
  void dispose() {
    _shadows?.dispose();
    super.dispose();
  }

  @override
  bool get alwaysNeedsAddToScene => true;
  @override
  void addToScene(ui.SceneBuilder builder) {
    data.prepare(this);
    _prepareShadows();
    if (_shadows != null) builder.addPicture(Offset.zero, _shadows!);
    addChildrenToScene(builder);
  }
}

class _GlassBatch {
  _GlassBatch() : shader = LiquidPrism._batchProgram!.fragmentShader() {
    shader.setImageSampler(
      0,
      LiquidPrism._linearSampler!,
      filterQuality: ui.FilterQuality.low,
    );
  }
  final BackdropKey key = BackdropKey();
  final ui.FragmentShader shader;
  late ui.ImageFilter filter;
  final _filterCache = _GlassFilterCache();
}

class _GlassGroupGeometry {
  _GlassGroupGeometry({
    required this.transform,
    required this.bounds,
    required this.painted,
    required this.sampled,
    required this.footprint,
    required this.aligned,
  });

  final Matrix4 transform;
  final Rect bounds;
  final Rect painted;
  final Rect sampled;
  final Rect footprint;
  final bool aligned;

  factory _GlassGroupGeometry.measure(_RenderGlass member) {
    final transform = member.glassTransform();
    final rect = member.shape.rect(member.size);
    final globalRect = MatrixUtils.transformRect(transform, rect);
    final aligned = _pixelAlignedRect(globalRect, member.pixelRatio);
    final bounds = MatrixUtils.transformRect(transform, rect.inflate(2));
    final painted = MatrixUtils.transformRect(transform, rect.inflate(18));
    // Refraction/dispersion and the anisotropic pixel footprint stay inside
    // this conservative local sampling envelope. Reflections reach outward.
    final displacement = math.min(
      member.style.refraction,
      math.min(rect.width, rect.height) * .55,
    );
    final spread = member.style.dispersion * (2 + displacement * .12);
    final reach = member.style.reflection > .001
        ? math.max(
            member.style.reflectionReach,
            1 + member.style.reflectionReach / 3,
          )
        : 0.0;
    final margin =
        math.max(displacement * .5 + spread, reach) +
        member.frostReach * 3 +
        20;
    // Exact outward reach of the optical pass: reflection taps, or dispersion
    // plus half of the bounded 16px footprint, then the frost kernel (3σ).
    final outside =
        math.max(
          member.style.reflection > .001 ? member.style.reflectionReach : 0,
          spread + 8 / member.pixelRatio,
        ) +
        member.frostReach * 3 +
        1;
    final sampled = MatrixUtils.transformRect(transform, rect.inflate(outside));
    final footprint = MatrixUtils.transformRect(
      transform,
      rect.inflate(margin),
    ).inflate(8 / member.pixelRatio);
    return _GlassGroupGeometry(
      transform: transform,
      bounds: bounds,
      painted: painted,
      sampled: sampled,
      footprint: footprint,
      aligned: aligned,
    );
  }

  bool isNear(_GlassGroupGeometry other) =>
      footprint.overlaps(other.bounds) || other.footprint.overlaps(bounds);

  bool conflictsWith(_GlassGroupGeometry other) =>
      sampled.overlaps(other.painted) || other.sampled.overlaps(painted);

  bool get hasUnitScale {
    final m = transform.storage;
    return m[0] == 1 &&
        m[5] == 1 &&
        m[1] == 0 &&
        m[4] == 0 &&
        m[3] == 0 &&
        m[7] == 0 &&
        m[15] == 1;
  }
}

class _GlassGroupData {
  final members = <_RenderGlass>{};
  final prepared = <_RenderGlass, _GlassBatch>{};

  /// Scalar members reading one backdrop capture, each with its own filter.
  final shared = <_RenderGlass>{};
  final sharedKey = BackdropKey();

  /// One capture for every hoisted frost pass; the optical passes then share
  /// a second capture that already holds each member's frost.
  final frostKey = BackdropKey();
  final _batches = <_GlassBatch>[];
  bool _disposed = false;

  /// Clips between a shared member and the group layer, in root
  /// logical coordinates, applied again to whatever the hoist paints for it.
  final _clips = <RenderObject, List<Path>>{};

  _RenderGlass? _hoistHost;
  ui.Picture? _sharedShadows;
  List<Object> _sharedSignature = [];

  /// Paints shared shadows and frost before the first shared optical pass.
  void _hoist(ui.SceneBuilder builder, _RenderGlass host, Offset offset) {
    final hostInverse = Matrix4.inverted(host.getTransformTo(null));
    final toHost = Matrix4.translationValues(offset.dx, offset.dy, 0)
      ..multiply(hostInverse);
    final transforms = <_RenderGlass, Matrix4>{};
    final clips = <RenderObject, List<Path>>{};
    final signature = <Object>[offset, host];
    for (final member in shared) {
      final matrix = toHost.clone()..multiply(member.glassTransform());
      transforms[member] = matrix;
      clips[member] = [
        for (final clip in _clips[member] ?? const <Path>[])
          clip.transform(toHost.storage),
      ];
      signature.addAll([
        member,
        member.shape,
        member.size,
        member.recipe.shadowStrength,
        member.recipe.usesNativeControlShadow,
        ...matrix.storage,
        for (final clip in clips[member]!) clip.getBounds(),
      ]);
    }
    if (!listEquals(_sharedSignature, signature)) {
      _sharedSignature = signature;
      _sharedShadows?.dispose();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final entry in transforms.entries) {
        canvas.save();
        for (final clip in clips[entry.key]!) {
          canvas.clipPath(clip);
        }
        canvas.transform(entry.value.storage);
        _ExteriorShadow(
          entry.key.shape,
          strength: entry.key.recipe.shadowStrength,
          nativeControl: entry.key.recipe.usesNativeControlShadow,
        ).paint(canvas, entry.key.size);
        canvas.restore();
      }
      _sharedShadows = recorder.endRecording();
    }
    builder.addPicture(Offset.zero, _sharedShadows!);
    var index = 0;
    for (final entry in transforms.entries) {
      final member = entry.key;
      final contour = member.shape
          .path(member.size)
          .transform(entry.value.storage);
      final frost = member._frostLayer.layer;
      final passes = member.frost;
      if (frost == null || passes.isEmpty) continue;
      final memberClips = clips[member]!;
      for (final clip in memberClips) {
        builder.pushClipPath(clip);
      }
      builder.pushClipPath(contour);
      final count = math.min(passes.length, frost._filters.length);
      for (var i = 0; i < count; i++) {
        frost.configure(i, passes[i], frostKey, offset: index++ * 1e-4);
        frost.pass(i).addToScene(builder);
      }
      builder.pop();
      for (final _ in memberClips) {
        builder.pop();
      }
    }
  }

  /// Clips to reapply to shared shadows/frost, in root logical coordinates.
  /// Null when a saveLayer, opacity, filter or mask prevents sharing.
  static List<Path>? _clipsToGroup(
    Layer? layer,
    Layer groupLayer,
    double pixelRatio,
  ) {
    final clips = <Path>[];
    for (var ancestor = layer; ancestor != groupLayer;) {
      if (ancestor == null) return null;
      Path? path;
      switch (ancestor) {
        case ClipRectLayer(:final clipRect?, :final clipBehavior)
            when clipBehavior != Clip.antiAliasWithSaveLayer:
          path = Path()..addRect(clipRect);
        case ClipRRectLayer(:final clipRRect?, :final clipBehavior)
            when clipBehavior != Clip.antiAliasWithSaveLayer:
          path = Path()..addRRect(clipRRect);
        case ClipRSuperellipseLayer(
              :final clipRSuperellipse?,
              :final clipBehavior,
            )
            when clipBehavior != Clip.antiAliasWithSaveLayer:
          path = Path()..addRSuperellipse(clipRSuperellipse);
        case ClipPathLayer(:final clipPath?, :final clipBehavior)
            when clipBehavior != Clip.antiAliasWithSaveLayer:
          path = clipPath;
        case OffsetLayer() || TransformLayer() || AnnotatedRegionLayer():
          break;
        case _ when ancestor.runtimeType == ContainerLayer:
          break;
        default:
          return null;
      }
      if (path != null) {
        // Layer transforms compose to physical pixels; the root applies the
        // device pixel ratio, which hoisted geometry handles itself.
        final toRoot = Matrix4.diagonal3Values(
          1 / pixelRatio,
          1 / pixelRatio,
          1,
        )..multiply(compositedTransform(ancestor));
        clips.add(path.transform(toRoot.storage));
      }
      ancestor = ancestor.parent;
    }
    return clips;
  }

  void prepare(_GlassGroupLayer groupLayer) {
    prepared.clear();
    shared.clear();
    _clips.clear();
    _hoistHost = null;
    if (_disposed) return;
    final canBatch = LiquidPrism._batchProgram != null;
    final surfaces = members
        .where(
          (m) =>
              m.attached &&
              m.hasSize &&
              !m.size.isEmpty &&
              m.getTransformTo(null).determinant() != 0,
        )
        .toList();
    final geometry = {
      for (final member in surfaces)
        member: _GlassGroupGeometry.measure(member),
    };
    final groups = <double, List<_RenderGlass>>{};
    for (final member in surfaces) {
      final measured = geometry[member]!;
      final near = surfaces.any(
        (other) => other != member && measured.isNear(geometry[other]!),
      );
      // Relocating shadows across an intermediate clip/saveLayer would alter
      // their visibility or their source pixels. Retain normal paint order.
      var ancestor = member._clipLayer.layer?.parent;
      var independentLayers = true;
      while (ancestor != null && ancestor != groupLayer) {
        if (ancestor is! OffsetLayer &&
            ancestor is! TransformLayer &&
            ancestor.runtimeType != ContainerLayer) {
          independentLayers = false;
          break;
        }
        ancestor = ancestor.parent;
      }
      final sameLayers = independentLayers && ancestor == groupLayer;
      final clips = sameLayers
          ? const <Path>[]
          : _clipsToGroup(
              member._clipLayer.layer?.parent,
              groupLayer,
              member.pixelRatio,
            );
      final excluded = surfaces.any(
        (other) => other != member && measured.conflictsWith(geometry[other]!),
      );
      if (clips != null && !excluded) {
        shared.add(member);
        _clips[member] = clips;
      }
      // Clear, expert and tab-bar optics expose resampling differences in Impeller's
      // cached filter snapshot at high-contrast edges. Keep their scalar path.
      // A batch composes one plain frost into its filter; a blur fill that
      // blends over the sharp backdrop needs the member's own passes.
      if (!canBatch ||
          near ||
          !member.plainFrost ||
          member.shape.isSmooth ||
          member.recipe.kind != 1 ||
          member.recipe.role == GlassRole.tabBar) {
        continue;
      }
      // Cached output adds a resampling step. Fractional device-pixel edges or
      // a changed basis retain the scalar path, preserving the animated rim.
      if (!sameLayers ||
          !measured.aligned ||
          member.pixelRatio < 1 ||
          !measured.hasUnitScale) {
        continue;
      }
      groups.putIfAbsent(member.style.frost, () => []).add(member);
    }
    _prepareBatches(groups, geometry);
    shared.removeAll(prepared.keys);
    if (shared.length < 2) shared.clear();
  }

  void _prepareBatches(
    Map<double, List<_RenderGlass>> groups,
    Map<_RenderGlass, _GlassGroupGeometry> geometry,
  ) {
    var used = 0;
    for (final group in groups.values) {
      for (var start = 0; start < group.length; start += batchMaxLenses) {
        final chunk = group.skip(start).take(batchMaxLenses).toList();
        if (chunk.length < 2) continue;
        if (used == _batches.length) _batches.add(_GlassBatch());
        final batch = _batches[used++];
        final values = <double>[0, 0, chunk.length.toDouble()];
        for (final member in chunk) {
          final rect = geometry[member]!.bounds;
          final dpr = member.pixelRatio;
          final uniforms = member.uniforms(geometry[member]!.transform);
          values.addAll(batchLensUniforms(rect, dpr, uniforms));
          prepared[member] = batch;
        }
        batch.filter = batch._filterCache.resolve(
          batch.shader,
          values,
          chunk.first.style.frost,
        );
      }
    }
    while (_batches.length > used) {
      _batches.removeLast().shader.dispose();
    }
  }

  void dispose() {
    _disposed = true;
    prepared.clear();
    shared.clear();
    _clips.clear();
    members.clear();
    _sharedShadows?.dispose();
    _sharedShadows = null;
    for (final batch in _batches) {
      batch.shader.dispose();
    }
    _batches.clear();
  }
}

bool _pixelAlignedRect(Rect rect, double pixelRatio) {
  for (final value in [rect.left, rect.top, rect.right, rect.bottom]) {
    final physical = value * pixelRatio;
    if (!physical.isFinite ||
        (physical - physical.roundToDouble()).abs() >= 1e-6) {
      return false;
    }
  }
  return true;
}

/// One lens of the batch shader's `u_lenses`: [batchLensStride] floats.
@visibleForTesting
List<double> batchLensUniforms(Rect bounds, double dpr, List<double> scalar) =>
    [
      bounds.left * dpr,
      bounds.top * dpr,
      bounds.right * dpr,
      bounds.bottom * dpr,
      ...scalar.skip(2).take(44),
      ...scalar.skip(46 + superellipseUniformCount).take(20),
    ];

/// Floats per lens in the batch shader (seventeen vec4).
@visibleForTesting
const batchLensStride = 68;

/// Lenses per batch: `u_lenses` holds 256 vec4.
@visibleForTesting
const batchMaxLenses = 15;
