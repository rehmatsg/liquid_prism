#include <flutter/runtime_effect.glsl>
precision highp float;

// Carries a blurred backdrop to the optical pass in the framebuffer's alpha.
// Drawn with BlendMode.modulate, the white colour leaves the sharp backdrop
// untouched while alpha stores the blur: columns repeat marker (1), red,
// green and blue, each colour scaled to at most 0.9. The blur varies slowly,
// so the optical pass rebuilds it from four neighbouring pixels
// (readFill in glass_core.glsl).
// ImageFilter ABI: the engine supplies the input texture size.
uniform vec2 u_textureSize;
uniform sampler2D u_texture;
out vec4 frag_color;

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 uv = p / u_textureSize;
#ifdef IMPELLER_TARGET_OPENGLES
#ifndef IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED
  uv.y = 1.0 - uv.y;
#endif
#endif
  vec3 blurred = clamp(texture(u_texture, uv).rgb, 0.0, 1.0) * 0.9;
  float column = mod(floor(p.x), 4.0);
  float value = column < 0.5 ? 1.0
      : (column < 1.5 ? blurred.r : (column < 2.5 ? blurred.g : blurred.b));
  frag_color = vec4(1.0, 1.0, 1.0, value);
}
