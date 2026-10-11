#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 u_textureSize;
uniform float u_count;
uniform vec4 u_lenses[256];
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
vec4 u_tintRed;
vec4 u_tintGreen;
vec4 u_tintBlue;
vec4 u_state;
const vec4 u_shapeA = vec4(0.);
const vec4 u_shapeB = vec4(0.);
const vec4 u_shapeC = vec4(0.);
const vec4 u_shapeD = vec4(0.);
vec4 u_curve[65];
vec4 u_derived[4];
#include "glass_core.glsl"
void main() {
    vec2 p = FlutterFragCoord().xy;
    int slot = -1;
    for (int i = 0; i < 16; i++) {
        if (float(i) >= u_count) break;
        vec4 bounds = u_lenses[i * 16];
        if (p.x >= bounds.x && p.y >= bounds.y && p.x <= bounds.z && p.y <= bounds.w) {
            slot = i * 16;
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
    u_tintRed = u_lenses[slot + 8];
    u_tintGreen = u_lenses[slot + 9];
    u_tintBlue = u_lenses[slot + 10];
    u_state = u_lenses[slot + 11];
    u_derived[0] = u_lenses[slot + 12];
    u_derived[1] = u_lenses[slot + 13];
    u_derived[2] = u_lenses[slot + 14];
    u_derived[3] = u_lenses[slot + 15];
    shadeGlass();
}
