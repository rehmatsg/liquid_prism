#include <flutter/runtime_effect.glsl>
precision highp float;


uniform vec2 u_frame;
uniform vec4 u_anchor;
uniform vec4 u_tongue;
uniform vec2 u_shape;
uniform vec2 u_outline;

out vec4 frag_color;

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

float neck(vec2 p, float h, float radius) {
  p.y -= clamp(p.y, 0.0, max(h, 0.0));
  return length(p) - radius;
}

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
  rim *= smoothstep(0.0, 2.0, anchor(p)) * u_outline.y;
  frag_color = vec4(vec3(rim * alpha), alpha);
}
