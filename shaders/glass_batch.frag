#include <flutter/runtime_effect.glsl>
precision highp float;
uniform vec2 u_textureSize;
uniform float u_count;
uniform float u_headroom;
uniform vec4 u_lenses[256];
uniform sampler2D u_backdrop;
out vec4 frag_color;
vec2 u_origin;
vec2 u_extent;
vec4 u_transform;
vec4 u_optics;
vec4 u_tint;
vec4 u_finish;
vec4 u_geometry;
vec4 u_material;
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
vec4 u_face;
const vec4 u_frost = vec4(0.,0.,0.,-1.);
#include "glass_core.glsl"
void main() {
    vec2 p = FlutterFragCoord().xy;
    bool hit = false;
    for (int i = 0; i < 15; i++) {
        if (float(i) >= u_count) break;
        vec4 bounds = u_lenses[i * 17];
        if (p.x >= bounds.x && p.y >= bounds.y && p.x <= bounds.z && p.y <= bounds.w) {
            vec4 geometry = u_lenses[i * 17 + 1];
            u_origin = geometry.xy;
            u_extent = geometry.zw;
            u_transform = u_lenses[i * 17 + 2];
            u_optics = u_lenses[i * 17 + 3];
            u_tint = u_lenses[i * 17 + 4];
            u_finish = u_lenses[i * 17 + 5];
            u_geometry = u_lenses[i * 17 + 6];
            u_material = u_lenses[i * 17 + 7];
            u_tintRed = u_lenses[i * 17 + 8];
            u_tintGreen = u_lenses[i * 17 + 9];
            u_tintBlue = u_lenses[i * 17 + 10];
            u_state = u_lenses[i * 17 + 11];
            u_derived[0] = u_lenses[i * 17 + 12];
            u_derived[1] = u_lenses[i * 17 + 13];
            u_derived[2] = u_lenses[i * 17 + 14];
            u_derived[3] = u_lenses[i * 17 + 15];
            u_face = u_lenses[i * 17 + 16];
            hit = true;
            break;
        }
    }
    if (hit) {
        shadeGlass();
    } else {
        frag_color = vec4(0.);
    }
}
