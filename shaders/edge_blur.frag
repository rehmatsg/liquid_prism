// Progressive edge blur: one separable Gaussian pass whose sigma ramps across
// a strip at the start and/or end of one axis of a box. Run twice, horizontal
// then vertical, as backdrop filters clipped to the strips.
#include <flutter/runtime_effect.glsl>
precision highp float;

// Engine-provided: the input texture's size in texture pixels. In the screen
// frame this is the live backdrop (the render pass, so texture px are physical
// px); in the texture frame it is the box's own offscreen raster, whose
// resolution the engine picks per frame. All box inputs are in logical px and
// reach texture px through the frame's matrix.
uniform vec2 u_size;
// Pass direction (0 horizontal, 1 vertical), fade axis (0 x, 1 y), frame
// (0 screen, 1 texture), box width in logical px.
uniform vec4 u_pass;
// Box height (logical px), box top-left in texture px (screen frame), unused.
uniform vec4 u_box;
// Screen frame: logical box px -> texture px, column-major (a, b | c, d):
// x' = a x + c y, y' = b x + d y.
uniform vec4 u_matrix;
// Its inverse, precomputed per surface.
uniform vec4 u_inverse;
// Start (top/left) strip: extent (logical px, 0 = off), max sigma (logical
// px), leading fraction held at full sigma, unused.
uniform vec4 u_start;
// End (bottom/right) strip, same layout.
uniform vec4 u_end;
uniform sampler2D u_texture;

out vec4 frag_color;

// Paired taps per side: 72 texels, or 3 sigma of a 24-texel sigma (an 8-point
// blur at 3x). Larger sigmas truncate their kernel; the loop ends early below.
#define MAX_PAIRS 36

// Smootherstep: zero first and second derivatives at both ends, the same curve
// as GlassFadeCurve in Dart so a blur and a fade over one strip track exactly.
float smootherstep01(float t) {
  return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Blur strength 1 -> 0 across a strip, with a solid plateau near the edge.
float ramp(float dist, float extent, float plateau) {
  if (extent <= 0.0) return 0.0;
  float t = clamp(dist / extent, 0.0, 1.0);
  if (t <= plateau) return 1.0;
  return 1.0 - smootherstep01((t - plateau) / (1.0 - plateau));
}

// Samples the input at p (texture px, Flutter orientation), clamped to bounds.
vec4 sampleTexture(vec2 p) {
  vec2 uv = clamp(p, vec2(0.0), u_size) / u_size;
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

  // The box frame: where its top-left sits in the texture and the matrix
  // taking logical box px to texture px. In the texture frame the texture is
  // the box itself, so the matrix is the raster scale.
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

  // The two strips sit on opposite edges, so summing is exact.
  float sigmaLogical =
      u_start.y * ramp(coord, u_start.x, u_start.z)
      + u_end.y * ramp(len - coord, u_end.x, u_end.z);
  if (sigmaLogical < 0.02) {
    frag_color = sampleTexture(xy);
    return;
  }

  // Blur direction in texture px, and the texture px per logical px along it.
  vec2 dir = vertical ? vec2(m[1][0], m[1][1]) : vec2(m[0][0], m[0][1]);
  float stretch = max(length(dir), 0.0001);
  dir /= stretch;
  float sigma = sigmaLogical * stretch; // texture px

  // The tap line runs along one of the box's own axes, so the strip
  // replicates the box's edge by limiting how far the taps may travel toward
  // each end of that axis. The limits sit half a texel inside the edge: a tap
  // on the boundary itself would land between the last texel inside the box
  // and the first one beyond it.
  float along = vertical ? p.y : p.x;
  float lenAlong = vertical ? boxSize.y : boxSize.x;
  float maxBack = max(along * stretch - 0.5, 0.0);
  float maxForward = max((lenAlong - along) * stretch - 0.5, 0.0);

  // Gaussian weights by incremental coefficients instead of an exp per tap
  // (GPU Gems 3, ch. 40), and adjacent taps merged into one bilinear read at
  // their weighted midpoint, which halves the texture reads. The sampler is
  // bound linear for that purpose.
  vec3 g = vec3(1.0, exp(-0.5 / (sigma * sigma)), 0.0);
  g.z = g.y * g.y;
  float radius = 3.0 * sigma;
  vec4 total = sampleTexture(xy);
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
    total += (sampleTexture(xy + dir * min(offset, maxForward))
              + sampleTexture(xy - dir * min(offset, maxBack))) * w;
    totalWeight += 2.0 * w;
  }
  frag_color = total / totalWeight;
}
