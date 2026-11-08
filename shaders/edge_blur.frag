#include <flutter/runtime_effect.glsl>
precision highp float;

// Texture pixels. Other lengths are logical pixels mapped by u_matrix.
uniform vec2 u_size;
// Direction (0 horizontal, 1 vertical), fade axis (0 x, 1 y), frame, box width.
uniform vec4 u_pass;
// Box height, texture origin xy, unused.
uniform vec4 u_box;
uniform vec4 u_matrix;
uniform vec4 u_inverse;
// Extent, sigma, plateau, floor; top/left and bottom/right strips.
uniform vec4 u_start;
uniform vec4 u_end;
uniform sampler2D u_texture;

out vec4 frag_color;

// Paired taps span 72 texels: 3 sigma for an 8-point blur at 3x.
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
  vec2 p = inv * (xy - origin); // logical coords within the box

  float coord = axisY ? p.y : p.x;
  float len = axisY ? boxSize.y : boxSize.x;

  float sigmaLogical =
      u_start.y * ramp(coord, u_start.x, u_start.z, u_start.w)
      + u_end.y * ramp(len - coord, u_end.x, u_end.z, u_end.w);
  if (sigmaLogical < 0.02) {
    frag_color = sampleUV(xy / u_size);
    return;
  }

  vec2 dir = vertical ? vec2(m[1][0], m[1][1]) : vec2(m[0][0], m[0][1]);
  float stretch = max(length(dir), 0.0001);
  dir /= stretch;
  float sigma = sigmaLogical * stretch; // texture px

  float along = vertical ? p.y : p.x;
  float lenAlong = vertical ? boxSize.y : boxSize.x;
  // Keep bilinear taps half a texel inside the box.
  float maxBack = max(along * stretch - 0.5, 0.0);
  float maxForward = max((lenAlong - along) * stretch - 0.5, 0.0);

  // Incremental Gaussian weights (GPU Gems 3, ch. 40); pair adjacent taps.
  vec3 g = vec3(1.0, exp(-0.5 / (sigma * sigma)), 0.0);
  g.z = g.y * g.y;
  // Truncate under 0.4% of the kernel mass; retain narrow kernels in full.
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
    float w = w0 + w1;
    float offset = x0 + w1 / w;
    total += (sampleUV(uv + tapStep * min(offset, maxForward))
              + sampleUV(uv - tapStep * min(offset, maxBack))) * w;
    totalWeight += 2.0 * w;
  }
  frag_color = total / totalWeight;
}
