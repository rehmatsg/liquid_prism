#include <flutter/runtime_effect.glsl>
precision highp float;

// Fades a blurred backdrop by its depth inside a rounded surface: the native
// regular base blur is strongest deep in the face and halves toward the rim.
// ImageFilter ABI: the engine supplies the input texture size.
uniform vec2 u_textureSize;
uniform vec2 u_origin;     // Surface origin in device pixels.
uniform vec2 u_extent;     // Surface size in points.
uniform vec4 u_transform;  // Raster transform, as glass.frag.
uniform vec4 u_shape;      // Corner radius, device pixel ratio, deep depth, colour gain.
uniform vec2 u_opacity;    // Opacity at the deep face and at the rim.
uniform sampler2D u_texture;
out vec4 frag_color;

void main() {
  vec2 screen = FlutterFragCoord().xy;
  vec2 uv = clamp(screen, vec2(0.5), u_textureSize - 0.5) / u_textureSize;
#ifdef IMPELLER_TARGET_OPENGLES
#ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
  uv.y = 1.0 - uv.y;
#endif
#endif
  vec4 blurred = texture(u_texture, uv);
  float det = u_transform.x * u_transform.w - u_transform.y * u_transform.z;
  if (abs(det) < 0.00001) {
    frag_color = vec4(0.0);
    return;
  }
  mat2 inv = mat2(u_transform.w, -u_transform.z, -u_transform.y, u_transform.x) / det;
  vec2 local = inv * (screen - u_origin) / u_shape.y;
  vec2 q = abs(local - u_extent * 0.5) - (u_extent * 0.5 - u_shape.x);
  float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - u_shape.x;
  float rim = clamp((d + u_shape.z) / max(u_shape.z, 0.001), 0.0, 1.0);
  // The gain saturates at the blurred colour's own coverage.
  blurred.rgb = min(blurred.rgb * u_shape.w, vec3(blurred.a));
  frag_color = blurred * mix(u_opacity.x, u_opacity.y, rim);
}
