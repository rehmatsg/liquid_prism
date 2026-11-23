#include <flutter/runtime_effect.glsl>
precision highp float;

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
