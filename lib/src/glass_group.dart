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
      signature.addAll([member.shape, member.size, ...matrix.storage]);
    }
    if (listEquals(_signature, signature)) return;
    _signature = signature;
    _shadows?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..translate(offset.dx, offset.dy);
    for (final entry in transforms.entries) {
      canvas.save();
      canvas.transform(entry.value.storage);
      _ExteriorShadow(entry.key.shape).paint(canvas, entry.key.size);
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

class _GlassGroupData {
  final members = <_RenderGlass>{};
  final prepared = <_RenderGlass, _GlassBatch>{};

  /// Scalar members reading one backdrop capture, each with its own filter.
  final shared = <_RenderGlass>{};
  final sharedKey = BackdropKey();
  final _batches = <_GlassBatch>[];
  bool _disposed = false;

  void prepare(_GlassGroupLayer groupLayer) {
    prepared.clear();
    shared.clear();
    if (_disposed) return;
    final canBatch = LiquidPrism._batchProgram != null;
    final surfaces = members
        .where((m) => m.attached && m.hasSize && !m.size.isEmpty)
        .toList();
    final bounds = <_RenderGlass, Rect>{};
    final footprints = <_RenderGlass, Rect>{};
    final painted = <_RenderGlass, Rect>{};
    final sampled = <_RenderGlass, Rect>{};
    // One render-tree walk per member per frame, shared by every use below.
    final transforms = <_RenderGlass, Matrix4>{};
    final aligned = <_RenderGlass>{};
    for (final member in surfaces) {
      final transform = transforms[member] = member.glassTransform();
      final rect = member.shape.rect(member.size);
      final globalRect = MatrixUtils.transformRect(transform, rect);
      if (_pixelAlignedRect(globalRect, member.pixelRatio)) {
        aligned.add(member);
      }
      bounds[member] = MatrixUtils.transformRect(transform, rect.inflate(2));
      // Everything a member paints, including its exterior shadow.
      painted[member] = MatrixUtils.transformRect(transform, rect.inflate(18));
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
          member.style.frost * 3 +
          20;
      // Exact outward reach of the optical pass: reflection taps, or dispersion
      // plus half of the bounded 16px footprint, then the frost kernel (3σ).
      final outside =
          math.max(
            member.style.reflection > .001 ? member.style.reflectionReach : 0,
            spread + 8 / member.pixelRatio,
          ) +
          member.style.frost * 3 +
          1;
      sampled[member] = MatrixUtils.transformRect(
        transform,
        rect.inflate(outside),
      );
      footprints[member] = MatrixUtils.transformRect(
        transform,
        rect.inflate(margin),
      ).inflate(8 / member.pixelRatio);
    }
    final groups = <double, List<_RenderGlass>>{};
    for (final member in surfaces) {
      final near = surfaces.any(
        (other) =>
            other != member &&
            (footprints[member]!.overlaps(bounds[other]!) ||
                footprints[other]!.overlaps(bounds[member]!)),
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
      // A shared capture omits whatever later members paint, shadows included.
      // Members whose sampling never reaches that content can share it; each
      // still applies its own scalar filter, so nothing is resampled.
      if (sameLayers &&
          !surfaces.any(
            (other) =>
                other != member &&
                (sampled[member]!.overlaps(painted[other]!) ||
                    sampled[other]!.overlaps(painted[member]!)),
          )) {
        shared.add(member);
      }
      // Clear, expert and tab-bar optics expose resampling differences in Impeller's
      // cached filter snapshot at high-contrast edges. Keep their scalar path.
      if (!canBatch ||
          near ||
          member.shape.isSmooth ||
          member.recipe.kind != 1 ||
          member.recipe.role == GlassRole.tabBar) {
        continue;
      }
      final matrix = transforms[member]!.storage;
      // Cached output adds a resampling step. Fractional device-pixel edges or
      // a changed basis retain the scalar path, preserving the animated rim.
      if (!sameLayers ||
          !aligned.contains(member) ||
          member.pixelRatio < 1 ||
          matrix[0] != 1 ||
          matrix[5] != 1 ||
          matrix[1] != 0 ||
          matrix[4] != 0 ||
          matrix[3] != 0 ||
          matrix[7] != 0 ||
          matrix[15] != 1) {
        continue;
      }
      groups.putIfAbsent(member.style.frost, () => []).add(member);
    }
    var used = 0;
    for (final group in groups.values) {
      for (var start = 0; start < group.length; start += 16) {
        final chunk = group.skip(start).take(16).toList();
        if (chunk.length < 2) continue;
        if (used == _batches.length) _batches.add(_GlassBatch());
        final batch = _batches[used++];
        final values = <double>[0, 0, chunk.length.toDouble()];
        for (final member in chunk) {
          final rect = bounds[member]!;
          final dpr = member.pixelRatio;
          values.addAll([
            rect.left * dpr,
            rect.top * dpr,
            rect.right * dpr,
            rect.bottom * dpr,
            ...member.uniforms(transforms[member]).skip(2).take(36),
          ]);
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
    shared.removeAll(prepared.keys);
    if (shared.length < 2) shared.clear();
  }

  void dispose() {
    _disposed = true;
    prepared.clear();
    shared.clear();
    members.clear();
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
