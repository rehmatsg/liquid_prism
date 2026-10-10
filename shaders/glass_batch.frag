#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 u_textureSize;
uniform float u_count;
uniform vec4 u_lenses[160];
uniform sampler2D u_backdrop;
out vec4 frag_color;
vec2 u_origin;
vec2 u_extent;
vec4 u_transform;
vec4 u_optics;   // Edge width, displacement, frost, dispersion.
vec4 u_tint;
vec4 u_finish;   // Saturation, light, reflection, splay.
vec4 u_geometry; // Radius, device pixel ratio, reflection reach, face brightness.
vec4 u_material; // Recipe (0 custom, 1 regular, 2 clear), dark, role, tint alpha.
vec4 u_tintSlope;
vec4 u_tintBias;
const vec4 u_shapeA = vec4(0.);
const vec4 u_shapeB = vec4(0.);
const vec4 u_shapeC = vec4(0.);
const vec4 u_shapeD = vec4(0.);
vec4 u_curve[65];
#include "glass_core.glsl"
void main() {
    vec2 p = FlutterFragCoord().xy;
    int slot = -1;
    for (int i = 0; i < 16; i++) {
        if (float(i) >= u_count) break;
        vec4 bounds = u_lenses[i * 10];
        if (p.x >= bounds.x && p.y >= bounds.y && p.x <= bounds.z && p.y <= bounds.w) {
            slot = i * 10;
            break;
        }
    }
    if (slot < 0) { frag_color = vec4(0.); return; }
    vec4 geometry = u_lenses[slot + 1];
    u_origin = geometry.xy;
    u_extent = geometry.zw;
    u_transform = u_lenses[slot + 2];
    u_optics = u_lenses[slot + 3];
    u_tint = u_lenses[slot + 4];
    u_finish = u_lenses[slot + 5];
    u_geometry = u_lenses[slot + 6];
    u_material = u_lenses[slot + 7];
    u_tintSlope = u_lenses[slot + 8];
    u_tintBias = u_lenses[slot + 9];
    shadeGlass();
}
