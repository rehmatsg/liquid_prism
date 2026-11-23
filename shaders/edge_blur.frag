#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2 u_size;
uniform vec4 u_pass;
uniform vec4 u_box;
uniform vec4 u_matrix;
uniform vec4 u_inverse;
uniform vec4 u_start;
uniform vec4 u_end;
uniform sampler2D u_texture;

out vec4 frag_color;

#define MAX_PAIRS 36

float smoothstep01(float t) {
  return t * t * (3.0 - 2.0 * t);
}

float ramp(float dist, float extent, float plateau, float floorStrength) {
  if (extent <= 0.0 || dist >= extent) return 0.0;
  float t = clamp(dist / extent, 0.0, 1.0);
  if (t <= plateau) return 1.0;
  float fall = 1.0 - smoothstep01((t - plateau) / (1.0 - plateau));
  return floorStrength + (1.0 - floorStrength) * fall;
}

vec4 sampleUV(vec2 uv) {
  uv = clamp(uv, 0.0, 1.0);
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(u_texture, uv);
}

void main() {
  vec2 xy = FlutterFragCoord().xy;
  vec2 boxSize = max(vec2(u_pass.w, u_box.x), vec2(1.0));
  bool vertical = u_pass.x > 0.5;
  bool axisY = u_pass.y > 0.5;

  vec2 origin;
  mat2 m;
  mat2 inv;
  if (u_pass.z > 0.5) {
    origin = vec2(0.0);
    vec2 scale = u_size / boxSize;
    m = mat2(scale.x, 0.0, 0.0, scale.y);
    inv = mat2(1.0 / scale.x, 0.0, 0.0, 1.0 / scale.y);
  } else {
    origin = u_box.yz;
    m = mat2(u_matrix.x, u_matrix.y, u_matrix.z, u_matrix.w);
    inv = mat2(u_inverse.x, u_inverse.y, u_inverse.z, u_inverse.w);
  }
  vec2 p = inv * (xy - origin);

  float coord = axisY ? p.y : p.x;
  float len = axisY ? boxSize.y : boxSize.x;

  float sigmaLogical =
      u_start.y * ramp(coord, u_start.x, u_start.z, u_start.w)
      + u_end.y * ramp(len - coord, u_end.x, u_end.z, u_end.w);
  if (sigmaLogical < 0.02) {
    frag_color = sampleUV(xy / u_size);
  } else {
    vec2 dir = vertical ? vec2(m[1][0], m[1][1]) : vec2(m[0][0], m[0][1]);
    float stretch = max(length(dir), 0.0001);
    dir /= stretch;
    float sigma = sigmaLogical * stretch;

    float along = vertical ? p.y : p.x;
    float lenAlong = vertical ? boxSize.y : boxSize.x;
    float maxBack = along * stretch - 0.5;
    float maxForward = (lenAlong - along) * stretch - 0.5;

    vec3 g = vec3(1.0, exp(-0.5 / (sigma * sigma)), 0.0);
    g.z = g.y * g.y;
    float radius = (sigma < 1.5 ? 3.0 : 2.88) * sigma;
    vec2 texel = 1.0 / u_size;
    vec2 uv = xy * texel;
    vec2 tapStep = dir * texel;
    vec4 total = sampleUV(uv);
    float totalWeight = 1.0;
    for (int i = 1; i <= MAX_PAIRS; i++) {
      float x0 = float(2 * i - 1);
      if (x0 > radius) break;
      g.xy *= g.yz;
      float w0 = g.x;
      g.xy *= g.yz;
      float w1 = g.x;
      float f0 = clamp(maxForward + 1.0 - x0, 0.0, 1.0) * w0;
      float f1 = clamp(maxForward - x0, 0.0, 1.0) * w1;
      float b0 = clamp(maxBack + 1.0 - x0, 0.0, 1.0) * w0;
      float b1 = clamp(maxBack - x0, 0.0, 1.0) * w1;
      float forward = f0 + f1;
      float back = b0 + b1;
      if (forward > 0.0) {
        total += sampleUV(uv + tapStep * (x0 + f1 / forward)) * forward;
      }
      if (back > 0.0) {
        total += sampleUV(uv - tapStep * (x0 + b1 / back)) * back;
      }
      totalWeight += forward + back;
    }
    frag_color = total / totalWeight;
  }
}
