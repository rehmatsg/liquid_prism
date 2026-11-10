#include <flutter/runtime_effect.glsl>
precision highp float;

// The pull-to-refresh drop: a black tongue that grows out of the Dynamic
// Island, a notch or the top edge and pinches off into a circle. Its joins are smooth
// unions with continuous curvature, the quality of iOS's continuous corners:
// a circular fillet would meet the island and the drop with a visible kink.
// All lengths are logical pixels in the painted layer's space.

// One physical pixel in logical pixels, then the drop's opacity.
uniform vec2 u_frame;
// Anchor: the island's left, top, width and height. A zero height selects a
// straight edge instead: the half-plane above y, the top of the layer or a
// notch's lower edge.
uniform vec4 u_anchor;
// Drop: centre x, the neck's upper end y, tip centre y, tip radius.
uniform vec4 u_tongue;
// Neck radius, union blend radius.
uniform vec2 u_shape;
// Inward white outline: width in logical pixels and opacity (zero in light).
uniform vec2 u_outline;

out vec4 frag_color;

// The cubic smooth minimum: unlike the quadratic one its result has a
// continuous second derivative, so curvature eases in and out of each join.
float smoothUnion(float a, float b, float k) {
  if (k <= 0.0) return min(a, b);
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * h * k / 6.0;
}

float stadium(vec2 p, vec4 rect) {
  vec2 half_size = rect.zw * 0.5;
  float radius = min(half_size.x, half_size.y);
  vec2 q = abs(p - rect.xy - half_size) - half_size + radius;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// A vertical capsule from the origin to (0, h). A negative radius keeps it
// away from every union.
float neck(vec2 p, float h, float radius) {
  p.y -= clamp(p.y, 0.0, max(h, 0.0));
  return length(p) - radius;
}

// The drop alone: its tip circle, joined to the neck that ties it to the
// anchor until it pinches off.
float drop(vec2 p) {
  vec2 q = p - u_tongue.xy;
  float h = u_tongue.z - u_tongue.y;
  float tip = length(q - vec2(0.0, h)) - u_tongue.w;
  return smoothUnion(tip, neck(q, h, u_shape.x), 14.0);
}

float anchor(vec2 p) {
  return u_anchor.w > 0.0 ? stadium(p, u_anchor) : p.y - u_anchor.y;
}

float shape(vec2 p) {
  float k = u_shape.y;
  if (u_anchor.w > 0.0) {
    // The drop leaves through the island's lower half; blending above its
    // middle would swell the top of the pill.
    k *= smoothstep(
      u_anchor.y + u_anchor.w * 0.5, u_anchor.y + u_anchor.w, p.y);
  }
  return smoothUnion(anchor(p), drop(p), k);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float pixel = u_frame.x;
  float distance = shape(p);
  float alpha = (1.0 - smoothstep(-pixel, pixel, distance)) * u_frame.y;
  float rim = smoothstep(-u_outline.x - pixel, -u_outline.x + pixel, distance);
  // Outline only the newly exposed contour, fading where it joins the sensor
  // housing. The existing island/notch must not gain a white border.
  rim *= smoothstep(0.0, 2.0, anchor(p)) * u_outline.y;
  frag_color = vec4(vec3(rim * alpha), alpha);
}
