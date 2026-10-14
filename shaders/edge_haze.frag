// The heavy half of a scroll edge effect: scales an already blurred input by
// a per-row weight, so composited over the pass it blends that blur into the
// content by that weight. Native bars blend a 16-point blur at half opacity,
// masked linearly from a third of the strip to its end (soft) or unmasked
// (hard). Pair it with ImageFilter.blur through ImageFilter.compose.
#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2 u_size;      // input texture size (engine)
// Fade axis (0 x, 1 y), frame (0 screen, 1 texture), box width, box height.
uniform vec4 u_pass;
// Box top-left in texture px (screen frame), unused.
uniform vec4 u_box;
uniform vec4 u_matrix;    // logical box px -> texture px, column-major
uniform vec4 u_inverse;
// Start strip: extent (0 = off), opacity, plateau (fraction held at full
// opacity; 1 holds it to the edge), unused.
uniform vec4 u_start;
uniform vec4 u_end;
uniform sampler2D u_texture;

out vec4 frag_color;

float weight(float dist, float extent, float opacity, float plateau) {
  if (extent <= 0.0 || dist < 0.0 || dist >= extent) return 0.0;
  float t = dist / extent;
  if (t <= plateau || plateau >= 1.0) return opacity;
  return opacity * (1.0 - (t - plateau) / (1.0 - plateau));
}

void main() {
  vec2 xy = FlutterFragCoord().xy;
  vec2 boxSize = max(u_pass.zw, vec2(1.0));
  vec2 origin;
  mat2 inv;
  if (u_pass.y > 0.5) {
    origin = vec2(0.0);
    vec2 scale = u_size / boxSize;
    inv = mat2(1.0 / scale.x, 0.0, 0.0, 1.0 / scale.y);
  } else {
    origin = u_box.xy;
    inv = mat2(u_inverse.x, u_inverse.y, u_inverse.z, u_inverse.w);
  }
  vec2 p = inv * (xy - origin);
  bool axisY = u_pass.x > 0.5;
  float coord = axisY ? p.y : p.x;
  float len = axisY ? boxSize.y : boxSize.x;
  float w = weight(coord, u_start.x, u_start.y, u_start.z)
          + weight(len - coord, u_end.x, u_end.y, u_end.z);
  vec2 uv = clamp(xy, vec2(0.0), u_size) / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  // Past the screen's edge the engine's blur samples nothing, so near an edge
  // its premultiplied result is the average of fewer, partly transparent
  // texels: darker, with alpha below 1. Divide by that coverage to recover the
  // average of the texels that exist, as a clamped blur would give.
  vec4 c = texture(u_texture, uv);
  if (c.a > 0.001) c.rgb /= c.a;
  frag_color = vec4(c.rgb, 1.0) * clamp(w, 0.0, 1.0);
}
