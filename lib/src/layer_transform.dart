import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Maps [layer]'s paint coordinates to physical pixels as its ancestor layers
/// composite it, including the root view's device pixel ratio.
///
/// Unlike [RenderObject.getTransformTo], this omits a transform an ancestor
/// applies as an image filter. `Transform(filterQuality: ...)` composites an
/// `ImageFilter.matrix` layer: its content, including any backdrop a shader
/// filter inside reads, is rasterized into an offscreen layer before that
/// matrix moves it. A filter whose own input bounds are fixed (such as the tab
/// foreground lens) must therefore measure its raster scale here.
@internal
Matrix4 compositedTransform(Layer layer) {
  final path = <Layer>[layer];
  for (Layer? ancestor = layer.parent; ancestor != null;) {
    path.add(ancestor);
    ancestor = ancestor.parent;
  }
  final transform = Matrix4.identity();
  for (var index = path.length - 1; index > 0; index--) {
    (path[index] as ContainerLayer).applyTransform(path[index - 1], transform);
  }
  return transform;
}

/// Whether an ancestor moves a layer after it is rasterized, so that its
/// composited and laid-out geometry disagree by more than [tolerance] physical
/// pixels at any corner of [bounds].
///
/// [composited] maps the layer's paint coordinates to physical pixels (see
/// [compositedTransform]); [paintOffset] places [bounds] in those coordinates.
/// [global] maps [bounds] to logical screen coordinates, like
/// `getTransformTo(null)`.
@internal
bool transformedAfterRaster({
  required Matrix4 composited,
  required Offset paintOffset,
  required Matrix4 global,
  required double pixelRatio,
  required Rect bounds,
  double tolerance = 0.5,
}) {
  for (final corner in [
    bounds.topLeft,
    bounds.topRight,
    bounds.bottomLeft,
    bounds.bottomRight,
  ]) {
    final raster = MatrixUtils.transformPoint(composited, corner + paintOffset);
    final laidOut = MatrixUtils.transformPoint(global, corner) * pixelRatio;
    if ((raster - laidOut).distance > tolerance) return true;
  }
  return false;
}
